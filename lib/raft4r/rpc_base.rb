require 'eventmachine'

module Raft4r
	module RPC
		Request = Struct.new :node_id, :req_id, :method, :arguments
		Response = Struct.new :req_id, :code, :response

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
				p = Marshal.dump Response.new(req.req_id, 0, resp)
				r[0].send_data p
				#r[0].close_connection_after_writing
				@req_pool.delete req.to_id
				LOGGER.info req.inspect
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
				LOGGER.info "data"
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

		class RPCClientConn < EventMachine::Connection
			def initialize h
				@h = h
			end
			def receive_data data
				resp = Marshal.load(data)
				req = @h.pending[resp.req_id]
				return unless req
				@h.pending.delete resp.req_id
				req[1].call resp
			end
		end

		class EMRPCClient
			attr_reader :pending
			RPC_TIMEOUT = 10
			def initialize addr, port, node_id
				@addr = addr
				@port = port
				@current_reqid = Time.now.to_i + rand(1000)
				@pending = {}
				@node_id = node_id
				@us = EM.open_datagram_socket '127.0.0.1', 0, RPCClientConn, self
				EM.add_periodic_timer(RPC_TIMEOUT / 2) do
					now = Time.now
					s1 = @pending.size
					@pending.delete_if {|k,v| now - v[2] > RPC_TIMEOUT }
					timeout_rpcs = s1 - @pending.size
					LOGGER.warn "timeout rpcs: #{timeout_rpcs}" if timeout_rpcs > 0
				end
			end

			def method_missing method_sym, *arguments, &block
				@current_reqid += 1
				req = Request.new(@node_id, @current_reqid, method_sym, arguments)
				pack = Marshal.dump(req)
				@pending[req.req_id] = [req, block, Time.now]
				@us.send_datagram pack, @addr, @port
			end
		end
	end
end

