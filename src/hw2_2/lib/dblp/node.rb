# frozen_string_literal: true

require 'socket'
require 'json'

module DBLP
  class Node
    def initialize(uuid, port, logger = DBLP.logger)
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
      file_id = hash['file_id'].to_i
      backup = hash['backup']
      response = { uuid: @uuid, accept: accept.to_s }.to_json
      client.send(response, 0)
      return unless accept == true

      raw = ''
      while recved = client.recv(DBLP::MAX_RECV)
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
        file = DBLP::Compression.decompress(raw)

        FileUtils.mkdir_p './saved_data/main'
        FileUtils.mkdir_p './saved_data/backup'
        if backup
          File.write("./saved_data/backup/#{file_id}.xml", file)
        else
          File.write("./saved_data/main/#{file_id}.xml", file)
        end
      rescue StandardError => e
        @logger.error(e.message.to_s)
      end

      response = { uuid: @uuid, success: 'true' }.to_json
      client.send(response, 0)
      @logger.debug("Successfully received file_id = #{file_id}, raw_size = #{raw.size}")
    end

    def query(hash, client)
      name = hash['name']
      backup = hash['backup']

      count = 0
      begin
        base = './saved_data/main'
        base = './saved_data/backup' if backup

        data = []
        file_ids = []
        Dir.entries(base).each do |f|
          path = File.join(base, f)
          if File.file?(path)
            data.push(path)
            file_ids.push(File.basename(path, '.xml'))
          end
        end

        data.each do |d|
          tmp = `grep -o -i '#{name}' #{d} | wc -l`.to_i
          @logger.debug("#{d} has #{tmp} #{name}")
          count += tmp
        end
      rescue StandardError => e
        @logger.error(e.message.to_s)
      end

      file_ids.sort!
      response = { uuid: @uuid, count: count, backup: backup, file_id: file_ids }.to_json
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
