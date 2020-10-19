# frozen_string_literal: true

module Rush
  module PG
    ALL_PG = 8
    def self.id(file_id)
      file_id.hex % ALL_PG
    end
  end
end
