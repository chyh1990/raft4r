#!/usr/bin/env ruby
require 'raft4r'

dsl = Raft4r::FSMDrawer.new
dsl.instance_eval File.read(ARGV[0]), ARGV[0]
#dsl.dump
puts dsl.to_dot

