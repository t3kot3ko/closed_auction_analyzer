require "thor"
require "json"
require "yaml"

require_relative "./closed_auction"
require_relative "./detailed_auction"

def all_valid_columns
  return %w(url title end_price start_price end_date end_time bid_count)
end

class CLI < Thor
	class_option "max", type: :string
	class_option "min", type: :string
	class_option "page", type: :numeric, default: 1
	class_option "all", type: :boolean
	class_option "sort", type: :string, default: "cbits"
	class_option "order", type: :string, default: "d"

	desc "search ", "Search with passed word"
	option "outputs", type: :array, default: []
	option "format", type: :string, required: false
	def search(word)
		client = ClosedAuction::Client.new
		query = __create_query(word, options)

		entries = options[:all] ? client.search_all(query) : client.search(query)
		print_entries(entries, options[:outputs], options[:format])
	end

	desc "avr WORD", "Just obtain the average of end price of closed auction"
	def avr(word)
		client = ClosedAuction::Client.new
		query = __create_query(word, options)

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
		query = __create_query(word, options)

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

	private
	def __create_query(word, options)
		query = ClosedAuction::SearchQuery.new(word, 
																					 min: options[:min], 
																					 max: options[:max], 
																					 page: options[:page],
																					 sort: options[:sort],
																					 order: options[:order]
																					)
		return query
	end

	# outputs: columns to be displayed
	def print_entries(entries, outputs, format = "csv")
		columns = outputs.select{|o| all_valid_columns.include? o}
		columns = all_valid_columns if columns.empty?

		rows = entries.map do |e|
			columns.map{|c| e.send(c.to_sym)}
		end

		# print to console in specified format
		case format
		when /csv/
			puts columns.join(",")
			rows.each do |row|
				puts entry.join(",")
			end
		when /json/
			puts rows.map{|row| columns.zip(row).to_h}.to_json
		when /yml|yaml|/
			puts rows.map{|row| columns.zip(row).to_h}.to_yaml
		else
			L.fatal "Invalid output format: `#{format}`" and exit 1
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

