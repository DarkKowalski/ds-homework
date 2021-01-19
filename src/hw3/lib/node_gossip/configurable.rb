# frozen_string_literal: true

module Node
  module Configurable
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def config
        @config ||= Configuration.new
      end

      def configure
        yield(config)
      end
    end

    class Configuration
      attr_accessor :service_host, :service_port,
                    :gossip_port,
                    :gossip_introducer_host,
                    :gossip_introducer_port
      def initialize
        @service_host = '127.0.0.1'
        @service_port = 8000
        @gossip_port = 9000
      end
    end
  end
end

module Node
  include Node::Configurable
end
