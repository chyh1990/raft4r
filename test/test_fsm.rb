require 'test/unit'
require 'raft4r'
include Raft4r
class MyFSM < FSM
	attr_reader :t
	def initialize
		init :init
		state :init do
			enter do
				@t = 0
			end
			trigger :t1 do
				goto :done
			end
		end

		state :done do
			enter do
				@t = 1
			end
		end
	end
end

class FSMTest < Test::Unit::TestCase
	def setup
		@fsm = MyFSM.new
	end

	def test_reset
		@fsm.reset
		assert_equal @fsm.t, 0
		@fsm.on :t1
		assert_equal @fsm.t, 1
	end
end
