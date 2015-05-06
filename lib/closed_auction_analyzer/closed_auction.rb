require "net/http"
require "uri"
require "nokogiri"
require "date"
require "logger"

require "closed_auction_analyzer/exceptions"

L = Logger.new(STDOUT)
if ENV["DISABLE_LOGGER"] == "true"
	L.level = Logger::FATAL
end

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
	BASE_URL = "http://closedsearch.auctions.yahoo.co.jp/"
	BASE_URI = URI.parse(BASE_URL)

	def initialize
		@agent =  Net::HTTP.new(BASE_URI.host, BASE_URI.port)
	end

	def search(query)
		body = nil
		@agent.start do |http|
			url = "/closedsearch?#{query.build}"
			L.debug url
			response = http.get(url)
			body = response.body
		end

		doc = Nokogiri::HTML.parse(body)
		table = doc.css("#AS1m1.AS1m.ASic").first

		unless table
			L.debug "No result found"
			return []
		end

		return create_entries(table)
	end

	def search_all(base_query)
		query = base_query.dup	
		query.page = 1

		result = []
		loop do
			entries = self.search(query)
			break if entries.nil? || entries.empty?

			result += entries
			query.page += 1
		end

		return result
	end


	private
	def create_entry(tr)
		url = tr.css("td.i").first.css("a").first.attribute("href").value
		title = tr.css("td.a1").first.css("h3").first.text
		end_price = tr.css("td.pr1").first.css("span.ePrice").first.text
		start_price = tr.css("td.pr1").first.css("span.sPrice").first.text
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
	attr_accessor :page

	# istatus: status of item (0: all, 1: new, 2: used)
	# abranch: issued from (0: all, 1: store, 2: personal)
	# s1: column to be used for sorting (cbids: end price, bids: count of bits, end: end date)
	# o1: order (a: asc, d: desc)
	# per_page: 20, 50 or 100
	def initialize(word, min: nil, max: nil, istatus: 0, abranch: 0, sort: "cbids", order: "d", page: 1, per_page: 100)
		@page = page
		@per_page = per_page

		default_params = {
			ei: "UTF-8",
			auccat: 0,
			tab_ex: "commerce",
			price_type: "currentprice",
			slider: 0
		}
			
		@params = {
			va: word.split("\s").join("+"),
			min: min, 
			max: max,
			istatus: istatus, 
			abranch: abranch,
			s1: sort,
			o1: order, 
			n: @per_page
		}.merge(default_params).reject{|k, v| v.nil?}
	end

	def create_default(word)
		return SearchQuery.new(word)
	end

	def build
		result = 
			@params.merge(b: @per_page * (@page - 1) + 1)
			.map{|key, value| "#{key.to_s}=#{value.to_s}"}.join("&")
		return result
	end
end


if __FILE__ == $0
	require "closed_auction_analyzer/detailed_auction"

	client = ClosedAuction::Client.new
	query = ClosedAuction::SearchQuery.new("happy hacking lite")
	entries = client.search(query)

	entries.sort_by(&:end_price).each do |e|
		detailed = DetailedAuction::Client.new(e.url).parse
		p detailed
		puts "#{e.title}, #{e.end_price}"
	end
end

