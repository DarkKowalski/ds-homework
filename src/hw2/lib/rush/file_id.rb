# frozen_string_literal: true

require 'digest'

module Rush
  module FileId
    def self.hex(str)
      seed = str.delete(" \t\r\n").downcase
      Digest::SHA256.hexdigest(seed)
    end
  end
end
