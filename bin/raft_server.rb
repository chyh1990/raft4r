#!/usr/bin/env ruby

require 'raft4r'
require 'yaml'

config = YAML.load(File.open('config/raft_cluster.yml').read)
server = Raft4r::RaftServer.new config, ARGV[0]
server.start_loop
