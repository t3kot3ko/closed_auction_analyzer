require_relative "./closed_auction"
require_relative "./detailed_auction"

search_word_arg = ARGV[0..-1]

if search_word_arg.empty?
	puts "Usage: [ruby] #{__FILE__} <search_words>"
	exit 1
end

search_word = search_word_arg.join(" ")

client = ClosedAuction::Client.new
query = ClosedAuction::SearchQuery.new(search_word)

entries = client.search(query)

def print_simple(e)
	puts "#{e.title}, #{e.end_price}, #{e.end_date}"
	puts "#{e.url}"
end

def print_verbose(e)
	puts "=== #{e.title}, #{e.end_price} ==="
	puts "#{e.url}"
	d_client = DetailedAuction::Client.new(e.url)
	parsed = d_client.parse

	puts "#{parsed.description}"
	puts
end

entries.sort_by(&:end_date).each do |e|
	verbose = ENV["VERBOSE"].nil?.!

	if verbose
		print_verbose e
	else
		print_simple e
	end
end

