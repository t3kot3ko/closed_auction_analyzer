require "logger"

module ClosedAuctionAnalyzer; end

class ClosedAuctionAnalyzer::SimpleLogger
	@@instance = nil
	attr_reader :L

	def initialize(out)
		@L = 
			if out
				Logger.new(STDOUT)
			else
				ClosedAuctionAnalyzer::DummyLogger.new
			end
	end

	def self.instance(out = true)
		@@instance = self.new(out) unless @@instance
		return @@instance
	end

	%i(debug info error fatal).each do |name|
		define_method(name) do |args|
			@@instance.L.send(name, *args)
		end
	end

end

class ClosedAuctionAnalyzer::DummyLogger
	%i(debug info error fatal).each do |name|
		define_method(name) do |args|
			# do nothing
		end
	end
end
