# frozen_string_literal: true

require 'logger'

module Rush
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

module Rush
  include Logging
end
