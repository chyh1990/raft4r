require 'test/unit'
require 'raft4r'

class RaftServerTest < Test::Unit::TestCase
	def test_start_server
		server = Raft4r::RaftServer.new '127.0.0.1', 7711
		server.start_loop
	end
end
