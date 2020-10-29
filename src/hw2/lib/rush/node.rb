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

      expected_size = hash['size'].to_i
      accept = expected_size < MAX_RECV
      pg_id = hash['pg'].to_i
      response = { uuid: @uuid, accept: accept.to_s }.to_json
      client.send(response, 0)
      return unless accept == true

      raw = ''
      while recved = client.recv(Rush::MAX_RECV)
        raw += recved
        @logger.debug("Reviced compressed file, size #{recved.size}")
        @logger.debug("expected_size = #{expected_size}, received_size = #{raw.size}")
        if raw.size == expected_size
          @logger.debug('Break')
          break
        end
        client.send('', 0)
        @logger.debug('Continue')
      end

      begin
        file = Rush::Compression.decompress(raw)
        FileUtils.mkdir_p "./saved_data/#{pg_id}"
        File.write("./saved_data/#{pg_id}/data.json", file)
      rescue StandardError => e
        @logger.error(e.message.to_s)
      end

      response = { uuid: @uuid, success: 'true' }.to_json
      client.send(response, 0)
      @logger.debug("Successfully received pg = #{pg_id}, raw_size = #{raw.size}")
    end

    def query(hash, client)
      id = hash['id']
      pg_id = hash['pg'].to_i

      count = 0
      list = []
      begin
        file = File.read("./saved_data/#{pg_id}/data.json")
        parsed = JSON.parse(file)
        parsed.each do |record|
          next unless record['id'] == id

          count = record['article_num']
          list = record['articles']
          @logger.debug("Found id = #{id}")
          break
        end
      rescue StandardError => e
        @logger.error(e.message.to_s)
      end

      response = { uuid: @uuid, count: count, list: list }.to_json
      client.send(response, 0)
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
        when 'query'
          query(hash, client)
        else
          @logger.warn("Invalid command #{hash['command']}")
        end
        client.close
      end
    end
  end
end
