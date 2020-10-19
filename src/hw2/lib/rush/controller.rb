# frozen_string_literal: true

require 'socket'
require 'timeout'
require 'json'
module Rush
  class Controller
    attr_reader :nodes, :sockets

    def initialize(logger = Rush.logger)
      @logger = logger
      @nodes = {}
      @sockets = {}

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
        @logger.warn("Invalid socket")
        return nil
      end

      response = nil
      begin
        Timeout.timeout(time) do
          socket.send(request.to_s, 0)
          response = socket.recv(MAX_RECV)
        end
      rescue Timeout::Error => e
        @logger.error(e.message.to_s)
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

    def send_file(localpath, socket)
      file = Rush::Compression.compress(File.read(localpath))
      request = { command: 'send_file', localpath: localpath.to_s, size: file.size.to_s }.to_json
      response = timeout_request(10, request, socket)

      hash = parse_json(response)
      return nil if hash.nil?
      @logger.debug("Node #{hash['uuid']} responds #{response}")
      return nil unless hash['accept']

      @logger.debug("Send file #{localpath} to Node #{hash['uuid']}")
      timeout_request(10, file, socket)
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
  end
end
