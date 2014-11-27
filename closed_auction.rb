require "net/http"
require "uri"
require "nokogiri"
require "date"

require_relative "./exceptions"


module ClosedAuction; end

class ClosedAuction::Entry < Struct.new(:url, :title, :end_price, :start_price, :end_date, :end_time, :bid_count)
	def initialize(url, title, end_price, start_price, end_date, end_time, bid_count)	
		# TODO: inline to create_entry
		start_price_formatted = start_price.gsub(" 円", "").gsub(",", "").to_i
		end_price_formatted = end_price.gsub(" 円", "").gsub(",", "").to_i
		end_date_formatted = Date.parse(end_date)
		bid_count = bid_count.to_i

		super(url, title, end_price_formatted, start_price_formatted, end_date_formatted, end_time,  bid_count)
	end
end


class ClosedAuction::Client
	BASE_URL = "http://closedsearch.auctions.yahoo.co.jp/jp/"
	BASE_URI = URI.parse(BASE_URL)

	def initialize
		@agent =  Net::HTTP.new(BASE_URI.host, BASE_URI.port)
	end

	def search(query)
		body = nil
		@agent.start do |http|
			url = "/closedsearch?#{query.build}"
			puts url
			response = http.get(url)
			body = response.body
		end

		doc = Nokogiri::HTML.parse(body)
		table = doc.css("#AS1m1.AS1m.ASic").first

		# even one result has not been found
		return [] unless table


		return create_entries(table)
	end


	private
	def create_entry(tr)
		url = tr.css("td.i").first.css("a").first.attribute("href").value
		title = tr.css("td.a1").first.css("h3").first.text

		end_price = tr.css("td.pr2").first.css("span.ePrice").first.text
		start_price = tr.css("td.pr2").first.css("span.sPrice").first.text
		end_date = tr.css("td.pr2").last.css("span.d").first.text
		end_time = tr.css("td.pr2").last.css("span.t").first.text
		bid_count = tr.css("td.bi").first.css("a").first.text

		unless [url, title, end_price, start_price, end_date, end_time].all?
			throw ::NodeNotFoundException
		end

		# format price
		[end_price, start_price].each{|e| e.gsub!(" 円", "")}
		return ::ClosedAuction::Entry.new(url, title, end_price, start_price, end_date, end_time, bid_count)
	end

	def create_entries(table)
		trs = table.xpath("//tr").select{|tr| tr.xpath("td").count >= 5}
		return trs.map{|tr| create_entry(tr)}
	end
	
end


class ClosedAuction::SearchQuery
	def initialize(word)
		@params = {
			p: word.split("\s").join("+"),
			ei: "UTF-8",
			auccat: 0,
			tab_ex: "commerce",
		}
	end

	def build
		result = @params.map{|key, value| "#{key.to_s}=#{value.to_s}"}.join("&")
		return result
	end
end


if __FILE__ == $0
	require_relative "./detailed_auction"

	client = ClosedAuction::Client.new
	query = ClosedAuction::SearchQuery.new("happy hacking lite")
	entries = client.search(query)

	entries.sort_by(&:end_price).each do |e|
		detailed = DetailedAuction::Client.new(e.url).parse
		p detailed
		puts "#{e.title}, #{e.end_price}"
	end
end

