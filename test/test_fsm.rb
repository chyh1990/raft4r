require 'test/unit'
require 'raft4r'
include Raft4r
class MyFSM < FSM
	attr_reader :t
	def do_helper
	end
	def initialize
		init :init
		state :init do
			enter do
				@t = 0
			end
			trigger :t1 do
				goto :done
			end
			trigger :t2 do |arg|
				do_helper
				@t = arg
				goto :s1
			end
		end

		state :done do
			enter do
				@t = 1
			end
		end

		state :s1 do
			trigger :t3 do
				goto :done
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

	def test_on_arguments
		@fsm.reset
		assert_equal @fsm.t, 0
		@fsm.on :t2, 3
		assert_equal @fsm.t, 3
	end
end
