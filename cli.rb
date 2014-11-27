require_relative "./closed_auction"

search_word_arg = ARGV[0..-1]

if search_word_arg.empty?
	puts "Usage: [ruby] #{__FILE__} <search_words>"
	exit 1
end

search_word = search_word_arg.join(" ")

client = ClosedAuction::Client.new
query = ClosedAuction::SearchQuery.new(search_word)

entries = client.search(query)

entries.sort_by(&:end_price).each do |e|
	puts "#{e.title}, #{e.end_price}"
end

