# frozen_string_literal: true

require 'socket'
require 'json'
require 'digest'

module Node
  class Server
    def initialize(config = Node.config)
      seed = "#{config.service_host}:#{config.service_port}"
      @uuid = Digest::SHA256.hexdigest(seed)
      @last_join = nil
      Node.logger.debug("Initialize Node: uuid = #{@uuid}")
    end

    def recv_file; end

    def query; end

    def listen; end
  end
end
