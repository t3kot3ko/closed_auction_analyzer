require "net/http"
require "uri"
require "nokogiri"
require "date"

BASE_URL = "http://closedsearch.auctions.yahoo.co.jp/jp/"
BASE_URI = URI.parse(BASE_URL)


class Entry < Struct.new(:url, :title, :end_price, :start_price, :end_date, :end_time, :bid_count)
	def initialize(url, title, end_price, start_price, end_date, end_time, bid_count)	
		start_price_formatted = start_price.gsub(" 円", "").gsub(",", "").to_i
		end_price_formatted = end_price.gsub(" 円", "").gsub(",", "").to_i
		end_date_formatted = Date.parse(end_date)
		bid_count = bid_count.to_i

		super(url, title, end_price_formatted, start_price_formatted, end_date_formatted, end_time,  bid_count)
	end
end

def create_entry(tr)
	url = tr.css("td.i").first.css("a").first.attribute("href").value
	title = tr.css("td.a1").first.css("h3").first.text

	end_price = tr.css("td.pr2").first.css("span.ePrice").first.text
	start_price = tr.css("td.pr2").first.css("span.sPrice").first.text
	end_date = tr.css("td.pr2").last.css("span.d").first.text
	end_time = tr.css("td.pr2").last.css("span.t").first.text

	[end_price, start_price].each{|e| e.gsub!(" 円", "")}

	bid_count = tr.css("td.bi").first.css("a").first.text

	return Entry.new(url, title, end_price, start_price, end_date, end_time, bid_count)
end

def create_entries(table)
	trs = table.xpath("//tr").select{|tr| tr.xpath("td").count >= 5}
	return trs.map{|tr| create_entry(tr)}
end

if __FILE__ == $0
	agent =  Net::HTTP.new(BASE_URI.host, BASE_URI.port)

	body = nil
	word = %w(happy hacking type-s).join("+")

	agent.start do |http|
		response = http.get("/closedsearch?p=#{word}&ei=UTF-8&auccat=0&tab_ex=commerce")
		body = response.body
	end

	doc = Nokogiri::HTML.parse(body)
	table = doc.css("#AS1m1.AS1m.ASic").first

	entries =  create_entries(table)

	entries.each do |e|
		puts "#{e.title}, #{e.end_price}"
	end
end




