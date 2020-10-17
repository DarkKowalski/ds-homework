# frozen_string_literal: true

require 'digest'

module Rush
  module FileId
    def self.hex(str)
      Digest::SHA256.hexdigest(str)
    end
  end
end
