require "thor"
require "json"
require "yaml"

require "closed_auction_analyzer/closed_auction"
require "closed_auction_analyzer/detailed_auction"

module ArrayEx
	refine Array do 
		# e.g.) [1, 8, 4] <=> [1, 7, 9]  #=> 1
		def <=>(other)
			self.zip(other).each do |s, o|
				next if s == o

				return -1 if s && !o
				return 1 if !s && o

				return s <=> o
			end
		end
	end
end


class CLI < Thor
	using ArrayEx

	class_option "max", type: :string, desc: "Max of end price"
	class_option "min", type: :string, desc: "Min of end price"
	class_option "page", type: :numeric, default: 1, desc: "Page index"
	class_option "all", type: :boolean, desc: "If selected, all available results are fetched"
	class_option "sort", type: :string, default: "cbids", desc: "Sorting key (cbids: end price, bids: count of bits, end: end date)"
	class_option "order", type: :string, default: "d", desc: "Ordering (a: asc, d: desc)"
	class_option "per_page", type: :numeric, default: 100, desc: "The number of fetched entries per page (20, 50 or 100)"
	class_option "filter", type: :array, default: [], desc: "Title filter (with v:WORD, entries whose title includes WORD are excluded)"

	class_option "debug", type: :boolean, default: false, desc: "Flag to show debug logs"

	desc "search WORD", "Search with passed word"
	option "outputs", type: :array, default: [], desc: "Columns to display (if empty, all columns are displayed)"
	option "format", type: :string, default: "csv", desc: "Output format (csv, yaml, or json)"
	def search(word)
		__configure(options)		

		entries = get_entries(word, options)
		print_entries(entries, options[:outputs], options[:format])
	end

	desc "avr WORD", "Just obtain the average of end price of closed auction"
	def avr(word)
		__configure(options)		

		entries = get_entries(word, options)
		if entries.empty?
			ClosedAuctionAnalyzer::SimpleLogger.instance.error "No entries found"
		else
		  puts entries.inject(0){|r, i| r += i.end_price}.to_f / entries.count
		end
	end

	desc "max WORD", "Just obtain the maximum of end price of closed auction"
  def max(word)
		entries = get_entries(word, options)
		if entries.empty?
			ClosedAuctionAnalyzer::SimpleLogger.instance.error "No entries found"
		else
			puts entries.map(&:end_price).max
		end
	end

	desc "min WORD", "Just obtain the minimum of end price of closed auction"
  def min(word)
		__configure(options)		

		entries = get_entries(word, options)
		if entries.empty?
			ClosedAuctionAnalyzer::SimpleLogger.instance.error "No entries found"
		else
			puts entries.map(&:end_price).min
		end
	end

	desc "histogram WORD", "Show a histogram of the end price distribution"
	option "star", {type: :boolean, default: false}
	option "scale", {type: :numeric, default: 1}
	option "interval", {type: :numeric}
	def histogram(word)
		__configure(options)

		entries = get_entries(word, options)
		prices = entries.map(&:end_price).sort

    # MEMO: example of generating histogram
		# prices = [1210, 1240, 1300, 1310, 1320, 1520], interval = 100
		# => [1200~1300: 2, 1300~1400: 3, 1400~1500: 0, 1500~1600: 1]

		min = prices.first
		max = prices.last

		# unless interval is set, it will be assigned automatically; e.x. 2345 -> 100
		interval = options[:interval] || 10 ** ([(max - min).to_s.size - 2, 0].max)
		unless interval > 0
			ClosedAuctionAnalyzer::SimpleLogger.instance.fatal "Interval must be >0" and exit 1
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

	
	option "outputs", type: :array, default: [], desc: "Columns to display (if empty, all columns are displayed)"
	desc "show URL", "Show detailed auction data in CLI"
	def show(url)
		__configure(options)

		outputs = options[:outputs]
		client = DetailedAuction::Client.new(url)
		entry = client.parse
		columns = outputs.select{|o| DetailedAuction::Entry::all_valid_columns.include? o}
		columns = DetailedAuction::Entry::all_valid_columns if columns.empty?

		columns.each do |column|
			puts "#{column}:"
			puts entry.send(column.to_sym)
		end
	end

	# TODO: consider to integrate into other command
	desc "group WORD", "Group entries by finished day, month or yeaar"
	option "index", type: :string, default: "day", desc: ""
	def group(word)
		__configure(options)		

		entries = get_entries(word, options)

		grouped_entries = 
			case options[:index]
			when "year"
				entries.group_by{|e| [e.end_date.year]}
			when "month"
				entries.group_by{|e| [e.end_date.year, e.end_date.month]}
			when "day"
				entries.group_by{|e| [e.end_date.year, e.end_date.month, e.end_date.day]}
			else
				entries.group_by{|e| [e.end_date.year, e.end_date.month, e.end_date.day]}
			end
		
		grouped_entries.keys.sort.each do |key|
			entries_in_group = grouped_entries.fetch(key)
			avr = entries_in_group.inject(0){|r, i| r += i.end_price}.to_f / entries_in_group.count
			date = key.join("/")
			puts "#{date}: #{avr}"
		end
	end

	private
	
	def __configure(options)
		# set logger
		ClosedAuctionAnalyzer::SimpleLogger.instance(options[:debug])
	end

	def get_entries(word, options)
		client = ClosedAuction::Client.new

		filter_options = options[:filter]
		query_options = options.reject{|k, v| k == :filter}
		query = __create_query(word, query_options)
		forward_filter, inverse_filter = __create_filter(filter_options)

		entries = options[:all] ? client.search_all(query) : client.search(query)

		# apply filter (all filters are evaluated by AND)
		if !forward_filter.empty? || !inverse_filter.empty?
			ClosedAuctionAnalyzer::SimpleLogger.instance.debug "forward: " + forward_filter.join(", ")
			ClosedAuctionAnalyzer::SimpleLogger.instance.debug "inverse: " + inverse_filter.join(", ")

			entries.select! do |entry| 
				title = entry.title
				forward_filter.all?{|f| title =~ /#{f}/i} && inverse_filter.all?{|inv| !(title =~ /#{inv}/i)}
			end
		end

		return entries
	end

	def __create_query(word, query_options)
		query = \
			ClosedAuction::SearchQuery.new(word, 
																		 min: query_options[:min], 
																		 max: query_options[:max], 
																		 page: query_options[:page],
																		 sort: query_options[:sort],
																		 order: query_options[:order],
																		 per_page: query_options[:per_page]
																		)
		return query
	end

	def __create_filter(filter_options)
		forward = []
		inverse = []

		filter_options.each do |f|
			if word = f.scan(/v:(.*)/).flatten.first
				inverse << word
			else
				forward << f
			end
		end

		return forward, inverse
	end

	# outputs: columns to be displayed
	def print_entries(entries, outputs, format = "csv")
		columns = outputs.select{|o| ClosedAuction::Entry::all_valid_columns.include? o}
		columns = ClosedAuction::Entry::all_valid_columns if columns.empty?

		rows = entries.map do |e|
			columns.map{|c| e.send(c.to_sym)}
		end

		# print to console in specified format
		case format
		when /csv/
			puts columns.join(",")
			rows.each do |row|
				puts row.join(",")
			end
		when /json/
			puts rows.map{|row| columns.zip(row).to_h}.to_json
		when /yml|yaml|/
			puts rows.map{|row| columns.zip(row).to_h}.to_yaml
		else
			ClosedAuctionAnalyzer::SimpleLogger.instance.fatal "Invalid output format: `#{format}`" and exit 1
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

