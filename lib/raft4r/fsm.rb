module Raft4r
	class StateScope
		attr_reader :name, :triggers, :onenter, :onleave
		def initialize name
			@name = name
			@triggers = {}
		end

		def trigger t, &block
			raise 'trigger already exists' if @triggers[t]
			@triggers[t] = block
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

		def set_current n
			raise "Invalid new state #{s}" unless @fsm_states[n]
			@fsm_current = n
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

		def on s
			curr = @fsm_states[@fsm_current]
			if curr.triggers[s]
				self.instance_eval(&curr.triggers[s])
			end
		end

		def goto s
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
	end

end
