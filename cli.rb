require "thor"
require_relative "./closed_auction"
require_relative "./detailed_auction"

def all_valid_columns
	return ["title", "url", "end_price", "end_date", "start_price", "start_date"]
end

class CLI < Thor
	class_option "max", type: :string
	class_option "min", type: :string
	class_option "page", type: :numeric, default: 1
	class_option "all", type: :boolean

	desc "search ", "Search with passed word"
	option "outputs", type: :array
	def search(word)
		client = ClosedAuction::Client.new
		query = ClosedAuction::SearchQuery.new(word, 
																					 min: options[:min], 
																					 max: options[:max], 
																					 page: options[:page]
																					)

		entries = options[:all] ? client.search_all(query) : client.search(query)
		print_entries(entries, options[:outputs])
	end

	desc "avr WORD", "Just obtain the average of end price of closed auction"
	def avr(word)
		client = ClosedAuction::Client.new
		query = ClosedAuction::SearchQuery.new(word, 
																					 min: options[:min], 
																					 max: options[:max], 
																					 page: options[:page]
																					)

		entries = options[:all] ? client.search_all(query) : client.search(query)
		puts entries.inject(0){|r, i| r += i.end_price}.to_f / entries.count
	end

	desc "histogram WORD", "Show a histogram of the end price distribution"
	option "star", {type: :boolean, default: false}
	option "scale", {type: :numeric, default: 1}
	option "interval", {type: :numeric}
	def histogram(word)
		# TODO: extract creation of client and query
		client = ClosedAuction::Client.new
		query = ClosedAuction::SearchQuery.new(word, 
																					 min: options[:min], 
																					 max: options[:max], 
																					 page: options[:page]
																					)

		entries = options[:all] ? client.search_all(query) : client.search(query)
		prices = entries.map(&:end_price).sort

		# MEMO: example of generating histogram
		# prices = [1210, 1240, 1300, 1310, 1320, 1520], interval = 100
		# => [1200~1300: 2, 1300~1400: 3, 1400~1500: 0, 1500~1600: 1]

		min = prices.first
		max = prices.last

		# unless interval is set, it will be assigned automatically; e.x. 2345 -> 100
		interval = options[:interval] || 10 ** ([(max - min).to_s.size - 2, 0].max)
		unless interval > 0
			L.fatal "Interval must be >0" and exit 1
		end

		s = min / interval 
		e = max / interval + 1
		digits = max.to_s.size

		result = []
		(s...e).each do |i|
			result << [i, prices.count{|price| i * interval <= price && price < (i + 1) * interval} / options[:scale]]
		end

		guide_format = "%#{digits.to_s}d"
		result.each do |i, count|
			puts "#{sprintf(guide_format, i * interval)} ~ #{sprintf(guide_format, (i + 1) * interval)}: #{options[:star] ? "*" * count : count.to_s}"
		end
	end

	# outputs: columns to be displayed
	def print_entries(entries, outputs)
		if outputs.nil? || outputs.empty?
			entries.each do |e|
				puts "#{e.title}, #{e.end_price}, #{e.end_date}"
				puts "#{e.url}"
			end
		else
			columns = outputs.select{|o| all_valid_columns.include? o}
			puts columns.join(",")
			entries.each do |e|
				puts columns.map{|c| e.send(c.to_sym)}.join(",")
			end
		end

	end

	def print_verbose(e)
		puts "=== #{e.title}, #{e.end_price} ==="
		puts "#{e.url}"
		d_client = DetailedAuction::Client.new(e.url)
		parsed = d_client.parse

		puts "#{parsed.description}"
		puts
	end

end

CLI.start(ARGV)

