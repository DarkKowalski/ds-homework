# frozen_string_literal: true

require 'socket'

module Rush
  class Node
    def initialize(uuid, port, logger = Rush.logger)
      @logger = logger
      @uuid = uuid
      @server = TCPServer.new(port)
      @logger.debug("Initialize Node: uuid = #{uuid}, port = #{port}")
    end

    def probe(client)
      client.puts @uuid
      @logger.info("Answer probe #{client.addr}")
    end

    def listen
      loop do
        client = @server.accept

        # get raw text from TCPSocket
        raw = client.gets
        next if raw.nil?

        @logger.debug("#{client} gets #{raw.chomp}")

        command = raw.to_s&.chomp
        case command.downcase
        when 'probe'
          probe(client)
        else
          @logger.warn("Invalid command #{command}")
        end
        client.close
      end
    end
  end
end
