# frozen_string_literal: true

require 'socket'
require 'timeout'
require 'json'

module DBLP
  class Controller
    attr_reader :nodes, :sockets

    def initialize(logger = DBLP.logger)
      @logger = logger
      @nodes = {}
      @sockets = {}
      @backup = {}

      @logger.debug('Initialize Controller')
    end

    def create_socket(ip, port)
      TCPSocket.new ip, port
    rescue StandardError => e
      @logger.error(e.message.to_s)
      nil
    end

    def timeout_request(time, request, socket)
      if socket.nil?
        @logger.warn('Invalid socket')
        return nil
      end

      response = nil
      begin
        Timeout.timeout(time) do
          socket.send(request.to_s, 0)
          response = socket.recv(MAX_RECV)
          @logger.debug("Timeout request, response = #{response}")
        end
      rescue Timeout::Error => e
        @logger.error("Time = #{time}, socket = #{socket}, err = #{e.message}")
        return nil
      end
      response
    end

    def parse_json(_json)
      hash = nil
      begin
        hash = JSON.parse(_json)
      rescue StandardError => e
        @logger.error(e.message.to_s)
        return nil
      end
      hash
    end

    def probe_socket(socket)
      @logger.debug("Probe socket #{socket}")

      request = { command: 'probe' }.to_json
      response = timeout_request(10, request, socket)

      hash = parse_json(response)
      return nil if hash.nil?

      hash['uuid']
    end

    def send_file(localpath, file_id, backup, socket)
      file = DBLP::Compression.compress(File.read(localpath))
      request = { command: 'send_file', localpath: localpath.to_s, size: file.size.to_s, file_id: file_id, backup: backup }.to_json
      response = timeout_request(10, request, socket)
      return nil if response.nil?

      hash = parse_json(response)
      return nil if hash.nil?

      @logger.debug("Node #{hash['uuid']} responds #{response}")
      return nil unless hash['accept']

      @logger.debug("Send file #{localpath} to Node #{hash['uuid']}")
      response = timeout_request(file.size, file, socket)
      hash = parse_json(response)
      return nil unless hash['success'] == 'true'

      @logger.debug("Successfully sent #{localpath}")
      file.size
    end

    def query_node(name, backup, socket)
      request = { command: 'query', name: name, backup: backup }.to_json
      response = timeout_request(10, request, socket)
      return nil if response.nil?

      hash = parse_json(response)
      @logger.debug("Node #{hash['uuid']} responds #{response}")

      hash
    end

    def probe_node(ip, port)
      @logger.debug("Probe Node #{ip}:#{port}")

      socket = create_socket(ip, port)
      return if socket.nil?

      uuid = probe_socket(socket)
      socket.close

      uuid
    end

    def add_node(ip, port)
      uuid = probe_node(ip, port)
      return if uuid.nil?

      uuid = uuid.to_s
      if @nodes.key?(uuid)
        @logger.warn("Duplicated Node #{uuid}")
        return
      end

      @nodes[uuid] = [ip, port]
      @logger.debug("Add Node #{uuid}, ip = #{ip}, port = #{port}")
    end

    def remove_node(uuid)
      uuid = uuid.to_s
      return unless @nodes.key?(uuid)

      disconnect_node(uuid)
      @nodes.delete(uuid)
      @logger.debug("Remove Node #{uuid}")
    end

    def connect_node(uuid)
      uuid = uuid.to_s
      return unless @nodes.key?(uuid) # Non-exsiting node

      ip, port = @nodes[uuid]
      socket = create_socket(ip, port)
      return if socket.nil?

      @sockets[uuid] = socket
      @logger.debug("Connect to Node #{uuid}, ip = #{ip}, port = #{port} #{socket}")
    end

    def disconnect_node(uuid)
      uuid = uuid.to_s
      return unless @sockets.key?(uuid)

      @sockets[uuid].close
      socket = @sockets.delete(uuid)
      @logger.debug("Disconnect from Node #{uuid}, #{socket}")
    end

    # Connect to all nodes
    def connect
      @nodes.each_key { |uuid| connect_node(uuid) }
    end

    # Disconnect from all nodes
    def disconnect
      @nodes.each_key { |uuid| disconnect_node(uuid) }
    end

    # Probe all nodes
    def probe
      @nodes.each do |uuid, ip_port|
        uuid = uuid.to_s
        if @sockets.key?(uuid)
          @logger.warn("Existing connection to Node #{uuid} #{@sockets[uuid]}")
          next
        end
        probe_node(*ip_port)
      end
    end

    def pick_osd(file_id)
      return nil if @nodes.size < DBLP::REPLICA

      keys = @nodes.keys.to_a.sort
      rand = Random.new(file_id).rand(0...keys.size)
      result = []
      DBLP::REPLICA.times do |n|
        index = (rand + n) % keys.size
        result.push(keys[index])
      end

      result
    end

    def distribute(localpath)
      data = []
      Dir.entries(localpath).each do |f|
        path = File.join(localpath, f)
        data.push(path) if File.file?(path)
      end
      data.sort!
      @logger.debug("Distribute data = #{data}")
      data.each do |d|
        file_id = File.basename(d, '.xml').to_i
        osd = pick_osd(file_id)
        return if osd.nil?

        @backup[osd[0].to_s] = osd[1]
        @logger.debug("Backup: #{osd[0]} -> #{osd[1]}")
        # send to main
        connect_node(osd[0])
        send_file(d, file_id, false, @sockets[osd[0]])
        disconnect_node(osd[0])

        # send to backup
        connect_node(osd[1])
        send_file(d, file_id, true, @sockets[osd[1]])
        disconnect_node(osd[1])
      end
    end

    def query(name)
      count = 0
      @nodes.each_key do |uuid|
        connect_node(uuid)
        response = query_node(name, false, @sockets[uuid])
        if response.nil?
          backup_id = @backup[uuid.to_s]
          @logger.debug("#{uuid} down, use backup #{backup_id}")
          connect_node(backup_id)
          response = query_node(name, true, @sockets[backup_id])
          disconnect_node(backup_id)
        else
          disconnect_node(uuid)
        end

        count += response['count'].to_i
      end
      count
    end

    def connected?
      if @nodes.empty?
        puts 'You are not connected to any node'
        return false
      end

      true
    end

    def start
      valid = ['- distribute [path]', '- add [host] [port]', '- query [name]', '- info', '- quit']
      puts valid
      loop do
        print 'controller $ '
        input = gets.chomp.downcase
        @logger.debug("User Input: #{input}")
        command = input.split(' ').to_a

        begin
          case command[0]
          when 'add'
            ip = command[1]
            port = command[2]
            result = add_node(ip, port)
            puts 'Done' unless result.nil?
          when 'distribute'
            next unless connected?

            path = command[1]
            result = distribute(path)
            puts 'Done' unless result.nil?
          when 'query'
            next unless connected?

            name = command.drop(1).join(' ')
            result = query(name)
            puts "Total: #{result}" unless result.nil?
          when 'info'
            puts "Nodes: #{@nodes}"
            puts "Backup: #{@backup}"
          when 'quit'
            puts 'Quit!'
            break
          else
            puts valid
          end
        rescue StandardError => e
          @logger.error(e.message.to_s)
        end
      end
    end
  end
end
