require 'delegate'
require 'logger'
require 'raft4r/rpc_base.rb'
require 'raft4r/fsm.rb'

module Raft4r
	VERSION = '0.1.0'
	LOGGER = Logger.new STDERR

	RaftCluster = Struct.new :config, :conn
	LogEntry = Struct.new :term, :log
	class RaftHandler
		#HEARTBEAT_TIMEOUT = 5
		#HEARTBEAT_TIMEOUT = 3
		#REELECT_TIMEOUT_MAX = 0.4
		ELECTION_TIMEOUT_MIN_MS = 2000
		HEARTBEAT_PER_TIMEOUT = 3
		attr_reader :node_id, :config

		include RPC::RPCMachine
		def initialize config, node_id
			@config = config
			@node_id = node_id
			@node_config = @config[node_id]

			@last_heartbeat = 0
			@cluster = {}
			
			# XXX debug only
			@election_timeout = (ELECTION_TIMEOUT_MIN_MS + rand(ELECTION_TIMEOUT_MIN_MS) ) / 1000.0
			# persistent state
			@current_term = 0
			@vote_for = nil
			@log = []

			@log << LogEntry.new(@current_term, nil)

			# volatile states
			@commit_index = 0
			@last_applied = 0

			# leader volatile
			@next_index = []
			@match_index = []

			# vote state
			@get_votes = {}
			@current_leader = nil
		end

		def on_init
			@config.each {|k,v|
				next if k == @node_id
				c = RaftCluster.new v, RPC::EMRPCClient.new(v['bind'], v['port'], @node_id)
				@cluster[k] = c
			}
			info "init: election_timeout #{@election_timeout}s"
			#p @cluster
			become_follower
			EM::PeriodicTimer.new(5) { print_state }
		end

		private
		def info str
			LOGGER.info "#{@node_id}: #{str}"
		end

		def print_state
			info "State: #{@state}, leader: #{@current_leader}, term: #{@current_term}"
		end

		def clear_timer
			@heartbeat_timer.cancel if @heartbeat_timer
		end

		def set_term term
			@current_term = term
			@vote_for = nil
			@get_votes = {}
			#reset_election_timer
			info "set term to #{@current_term}"
		end

		def on_election_timeout
			# ignore if i'm leader
			#return if @state == :leader
			case @state
			when :candidate
				info "election timout by candidate"
				start_new_election
			when :follower
				info "election timout by follower"
				become_candidate
			when :leader
				# empty
			end
		end

		def reset_election_timer
			@election_timer.cancel if @election_timer
			@election_timer = EM::PeriodicTimer.new(@election_timeout) { on_election_timeout }
		end


		def become_follower
			return if @state == :follower
			info "become follower"

			clear_timer
			@state = :follower
			reset_election_timer
		end

		def on_vote node_id
			@get_votes[node_id] = true
			if @get_votes.size > @cluster.size / 2
				info "get majority"
				become_leader
			end
		end

		def start_new_election
			fail 'ILLEGAL STATE' unless @state == :candidate
			info "start new election"
			# no leader...
			@current_leader = nil
			@get_votes = 0
			# reset election timer

			set_term @current_term + 1
			# random step back
			#timeout = (100 + rand(200)) / 1000.0
			# vote for self
			@vote_for = @node_id
			on_vote @node_id

			@cluster.each {|k,v|
				# XXX what if get reply in the future?
				v.conn.RequestVote @current_term, @node_id, @log.size, @log.last.term do |req, resp|
					next unless @state == :candidate
					info "Get vote from #{k}: #{resp.response[1]}"
					on_vote resp.node_id if resp.response[1]
				end
			}
		end

		def become_candidate
			return if @state == :candidate
			info "become candidate"
			clear_timer
			@state = :candidate

			start_new_election
		end

		def on_timer_heartbeat
			return unless @state == :leader

			#print_state
			@cluster.each { |k,v|
				# TODO
				v.conn.AppendEntries @current_term, @node_id, 0, 0, nil, 0
			}

		end

		def become_leader
			return if @state == :leader
			info "become leader"
			clear_timer
			@state = :leader
			@current_leader = @node_id

			info "start sending heartbeat"
			on_timer_heartbeat

			@heartbeat_timer = EM::PeriodicTimer.new(ELECTION_TIMEOUT_MIN_MS / 1000.0 / HEARTBEAT_PER_TIMEOUT) { on_timer_heartbeat }
		end

		def on_rpc_common req
			if req.arguments[0] > @current_term
				set_term req.arguments[0]
				become_follower
			end
		end

		public
		# on RPC request
		def AppendEntries req
			#info "AppendEntries from #{req.node_id}"
			# check req
			return [@current_term, false] if req.arguments[0] < @current_term
			on_rpc_common req
			# heartbeat from new leader
			if @state == :candidate && req.arguments[0] == @current_term
				become_follower
			end

			reset_election_timer
			@current_leader = req.node_id
			return [@current_term, true]
		end

		def RequestVote req
			info "RequestVote from #{req.node_id}"
			return [@current_term, false] if req.arguments[0] < @current_term
			on_rpc_common req

			# or @vote_for == candidateId??
			candidateId = req.arguments[1]
			if @vote_for.nil? || @vote_for == candidateId
				# if candidate is 'up-to-date'
				vote = false
				if @log.last.term < req.arguments[3]
					vote = true
				elsif @log.last.term == req.arguments[3]
					# longer log wins
					vote = req.arguments[2] >= @log.size
				end
				if vote
					info "Vote for #{candidateId}"
					@vote_for = candidateId
					reset_election_timer
					return [@current_term, true]
				else
					return [@current_term, false]
				end
			else
				# this node already voted
				return [@current_term, false]
			end
		end
	end


	class RaftServer
		# XXX handle cluster reconfig
		def initialize config, node_id
			s = config[node_id]
			raise 'Node not found' unless s

			@config = config
			@node_id = node_id
			@addr = s['bind']
			@port = s['port']
			LOGGER.info "Node: #{@node_id}, #{@addr}:#{@port}"
		end
		def start_loop
			LOGGER.info "Start RaftServer #{@addr}:#{@port}..."
			RPC::EMRPCServer.start_server @addr, @port, RaftHandler.new(@config, @node_id)
		end
	end
end

