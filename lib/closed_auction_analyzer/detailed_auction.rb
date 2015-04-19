require "net/http"
require "uri"
require "nokogiri"
require "date"

module DetailedAuction; end

class DetailedAuction::Entry < Struct.new(:price, :buynow_price, :bids, :starttime, :endtime, :description)
	def initialize(price, buynow_price, bids, starttime, endtime, description)
		[price, buynow_price].each do |e|
			e && e.gsub!("円", "") 
			e && e.gsub!(",", "")
		end

		price_formatted = price.to_i
		buynow_price_formatted = buynow_price.empty? ? nil : buynow_price.to_i

		super(price_formatted, buynow_price_formatted, bids, starttime, endtime, description)
	end

	def buynow?
		return self.buynow_price.nil?.!
	end
end

class DetailedAuction::Client
	def initialize(url)
		@parsed_url = URI.parse(url)
		@agent = Net::HTTP.new(@parsed_url.host, @parsed_url.port)
	end

	def parse
		body = nil
		@agent.start do |http|
			response = http.get(@parsed_url.path)
			body = response.body
		end

		doc = Nokogiri::HTML.parse(body)
		return create_entry(doc)
	end

	def create_entry(doc)
		price = doc.css("p.decTxtAucPrice").text
		buynow_price = doc.css("p.decTxtBuyPrice").text


		bids = doc.css("b[property='auction:Bids']").text.to_i

		starttime = doc.css("td[property='auction:StartTime']").text
		endtime = doc.css("td[property='auction:EndTime']").first.children.first.text

		description = doc.css("div.modUsrPrv#acMdUsrPrv").first.text.gsub("\n\n", "\n")

		return ::DetailedAuction::Entry.new(price, buynow_price, bids, starttime, endtime, description)
	end

	
end

if __FILE__ == $0
	url = "http://page11.auctions.yahoo.co.jp/jp/auction/n137117723"
	client = DetailedAuction::Client.new(url)

	entry = client.parse
	p entry
end
