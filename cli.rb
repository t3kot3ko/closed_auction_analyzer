require "thor"
require_relative "./closed_auction"
require_relative "./detailed_auction"

def all_valid_columns
	return ["title", "url", "end_price", "end_date", "start_price", "start_date"]
end

class CLI < Thor
	desc "search ", "Search with passed word"
	option "max", type: :string
	option "min", type: :string
	option "outputs", type: :array
	option "page", type: :numeric, default: 1
	option "all", type: :boolean
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

	option "max", type: :string
	option "min", type: :string
	option "all", type: :boolean
	option "page", type: :numeric, default: 1
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

