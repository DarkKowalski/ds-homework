# frozen_string_literal: true

require 'socket'
require 'json'

module Rush
  class Node
    def initialize(uuid, port, logger = Rush.logger)
      @logger = logger
      @uuid = uuid
      @server = TCPServer.new(port)
      @logger.debug("Initialize Node: uuid = #{uuid}, port = #{port}")
    end

    def probe(client)
      response = {uuid: @uuid}.to_json
      client.send(response, 0)
      @logger.info("Answer probe #{client.addr}")
    end

    def listen
      loop do
        client = @server.accept

        # get raw text from TCPSocket
        raw = client.recv(MAX_RECV)
        @logger.debug("#{client} gets #{raw.chomp}")

        hash = nil
        begin
          hash = JSON.parse(raw)
        rescue StandardError => e
          @logger.error(e.message.to_s)
        end
        next if hash.nil? || hash['command'].nil?

        case hash['command'].downcase
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
