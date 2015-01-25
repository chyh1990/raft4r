require 'test/unit'
require 'yaml'
require 'raft4r'

class RaftServerTest < Test::Unit::TestCase
	def setup
		@config = YAML.load(File.open('config/raft_cluster.yml').read)
	end
	def test_start_server
		server = Raft4r::RaftServer.new @config, 'n1'
		server.start_loop
	end
end
