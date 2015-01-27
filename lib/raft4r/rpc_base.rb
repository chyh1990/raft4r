require 'eventmachine'

module Raft4r
	module RPC
		# sender node_id
		Request = Struct.new :node_id, :req_id, :method, :arguments
		Response = Struct.new :node_id, :req_id, :code, :response

		class Request
			def to_id
				"#{node_id}_#{req_id}"
			end
		end

		class RPCMachine
			def initialize server_node_id
				@node_id = server_node_id
				@req_pool = Hash.new
			end

			def call_method conn, r
				# if the machine supports async call,
				# try it first
				if self.respond_to? :"Async#{r.method}"
					@req_pool[r.to_id] = [conn, r]
					self.__send__ r.method.to_sym, r
				else
					v = self.__send__ r.method.to_sym, r
					p = Marshal.dump Response.new(@node_id, r.req_id, 0, v)
					conn.send_data p
				end
			end

			def response_method req, resp
				r = @req_pool[req.to_id]
				return unless r
				p = Marshal.dump Response.new(@node_id, req.req_id, 0, resp)
				r[0].send_data p
				#r[0].close_connection_after_writing
				@req_pool.delete req.to_id
				#LOGGER.info req.inspect
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
				r = Marshal.load(data)
				@mach.call_method self, r
			end
		end

		class EMRPCServer
			def self.start_server addr, port, handler
				EM.run {
					handler.on_init if handler.respond_to? :on_init
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
				req[1].call req[0], resp if req[1]
			end
		end

		class EMRPCClient
			attr_reader :pending
			RPC_TIMEOUT = 1
			def initialize addr, port, sender_node_id
				@addr = addr
				@port = port
				@current_reqid = Time.now.to_i + rand(1000)
				@pending = {}
				@node_id = sender_node_id
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

