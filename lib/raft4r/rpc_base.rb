require 'eventmachine'

module Raft4r
	module RPC
		Request = Struct.new :node_id, :req_id, :method, :arguments
		Response = Struct.new :req_id, :code, :response

		class AsyncRPCServerHandler
			def oncall node_id, method, opts = {}
				raise NotImplementedError
			end
		end

		class Request
			def to_id
				"#{node_id}_#{req_id}"
			end
		end

		class RPCMachine
			def initialize
				@req_pool = Hash.new
			end

			def call_method conn, r
				@req_pool[r.to_id] = [conn, r]
				self.__send__ r.method.to_sym, r
			end

			def response_method req, resp
				r = @req_pool[req.to_id]
				return unless r

				r[0].send_data Marshal.dump(resp)
				r[0].close_connection_after_writing
				@req_pool.delete req.to_id
			end
		end

		class RPCConn < EventMachine::Connection
			def initialize mach
				super
				@mach = mach
			end
		
			def post_init
				#EM.add_periodic_timer(1) {puts "sec"}
			end

			def receive_data data
				#LOGGER.info "Data: #{data}"
				r = Marshal.load(data)
				@mach.call_method self, r
				#p r
				#send_data("wrong")
			end
		end

		class EMRPCServer
			def self.start_server addr, port, handler
				EM.run {
					us = EM.open_datagram_socket addr, port, RPCConn, handler
				}
			end
		end
	end
end

