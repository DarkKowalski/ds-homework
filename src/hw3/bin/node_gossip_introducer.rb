# frozen_string_literal: true

require_relative '../lib/node'

# load 'node_config.rb'

# or

# Node.configure do |config|
#  config.service_host = 'localhost'
#  config.gossip_port = '8000'
# end

Node::GossipServer.new.introduce
