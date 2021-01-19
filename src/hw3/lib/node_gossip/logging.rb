# frozen_string_literal: true

require 'logger'

module Node
  module Logging
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def logger
        @logger ||= Logger.new($stdout)
      end
    end
  end
end

module Node
  include Node::Logging
end
