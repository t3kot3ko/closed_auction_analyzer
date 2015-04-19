# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'closed_auction_analyzer/version'

Gem::Specification.new do |spec|
  spec.name          = "closed_auction_analyzer"
  spec.version       = ClosedAuctionAnalyzer::VERSION
  spec.authors       = ["Tomoyuki KAMIYA"]
  spec.email         = ["kamiya7140@gmail.com"]
  spec.summary       = %q{Analyzer of closed auction.}
	spec.description   = %q{Search closed auctions, provide their properties (e.g. end price, bit count, etc), calc average of end price, and show histogram of price distribution.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

	spec.add_dependency "nokogiri"
	spec.add_dependency "thor"
end
