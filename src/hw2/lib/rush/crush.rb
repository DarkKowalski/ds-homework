# frozen_string_literal: true

module Rush
  module Crush
    def self.pick(pg_id, nodes, num)
      return nil if nodes.size < num

      result = []
      keys = nodes.keys.to_a.sort
      rand = Random.new(pg_id).rand(0...keys.size)

      num.times do |n|
        index = (rand + n) % keys.size
        result.push(keys[index])
      end

      result
    end
  end
end
