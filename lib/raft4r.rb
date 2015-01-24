require 'delegate'
require 'logger'
require 'raft4r/rpc_base.rb'

module Raft4r
	VERSION = '0.1.0'
	LOGGER = Logger.new STDERR
	class RaftServer
		def initialize addr, port
			@addr = addr
			@port = port
		end

		class RaftHandler < RPC::RPCMachine
			def initialize
				super
				@states = :follower
			end

			def new_connection 
				LOGGER.info "INIT"
			end

			def AppendEntries req
				p req
				response_method req, RPC::Response.new
			end
		end

		def start_loop
			LOGGER.info "Start RaftServer #{@addr}:#{@port}..."
			RPC::EMRPCServer.start_server @addr, @port, RaftHandler.new
		end
	end
end
