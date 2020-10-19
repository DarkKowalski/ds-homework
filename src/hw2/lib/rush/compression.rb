# frozen_string_literal: true

require 'zlib'

module Rush
  module Compression
    def self.compress(input)
      Zlib::Deflate.deflate(input)
    end

    def self.decompress(input)
      Zlib::Inflate.inflate(input)
    end
  end
end
