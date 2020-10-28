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
      response = { uuid: @uuid }.to_json
      client.send(response, 0)
      @logger.info("Answer probe #{client.addr}")
    end

    def recv_file(hash, client)
      return if hash['size'].nil?

      accept = hash['size'].to_i < MAX_RECV
      pg_id = hash['pg'].to_i
      response = { uuid: @uuid, accept: accept.to_s}.to_json
      client.send(response, 0)
      return unless accept == true

      raw = client.recv(Rush::MAX_RECV)
      @logger.debug("Reviced compressed file, size #{raw.size}")

      file = Rush::Compression.decompress(raw)

      FileUtils.mkdir_p "./saved_data/#{pg_id}"
      File.write("./saved_data/#{pg_id}/data.json", file)

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
        when 'send_file'
          recv_file(hash, client)
        else
          @logger.warn("Invalid command #{hash['command']}")
        end
        client.close
      end
    end
  end
end
