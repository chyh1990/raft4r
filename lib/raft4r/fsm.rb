module Raft4r
	class StateScope
		attr_reader :name, :triggers, :onenter, :onleave
		def initialize name
			@name = name
			@triggers = {}
		end

		def trigger t, &block
			t = [t] if !(Array === t)
			t.each {|e|
				raise 'trigger already exists' if @triggers[e]
				@triggers[e] = block
			}
		end

		def enter &block
			@onenter = block
		end

		def leave &block
			@onleave = block
		end
	end

	class FSM
		def initialize &block
			self.instance_eval(&block) if block_given?
		end

		def current
			curr = @fsm_states[@fsm_current]
			raise "Invalid state #{s}" unless curr
			curr
		end

		def set_current s
			raise "Invalid new state #{s}" unless @fsm_states[s]
			@fsm_current = s
		end
		private :current, :set_current

		def init st
			@fsm_states = {}
			@fsm_current = nil
			@fsm_init = st
		end

		def state s, &block
			raise 'State already exists' if @fsm_states[s]
			ss = StateScope.new s
			ss.instance_eval(&block)
			@fsm_states[s] = ss
		end

		def on s, *arguments
			curr = @fsm_states[@fsm_current]
			if curr.triggers[s]
				self.instance_exec(*arguments, &curr.triggers[s])
			else
				STDERR.puts "State: #{@fsm_current}, trigger #{s} not exists"
			end
		end

		def goto s
			return if s == @current
			self.instance_eval(&current.onleave) if current.onleave
			set_current s
			self.instance_eval(&current.onenter) if current.onenter
		end

		def reset
			raise 'No init state' unless @fsm_init
			set_current @fsm_init
			self.instance_eval(&current.onenter) if current.onenter
		end

		def dump
			p self
		end

		def current_state
			@fsm_current
		end
	end

end
