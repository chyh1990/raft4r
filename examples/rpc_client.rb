require 'raft4r'
require 'socket'

EM.run {
	c = Raft4r::RPC::EMRPCClient.new '127.0.0.1', 7711, "n1"

	10.times {
		c.AppendEntries :help do |resp|
			p resp
			EM.stop
		end
	}
}

