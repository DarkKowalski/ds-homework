# frozen_string_literal: true

require 'socket'
require 'timeout'

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

    def probe_socket(socket)
      @logger.debug("Probe socket #{socket}")

      node_uuid = nil
      begin
        Timeout.timeout(10) do
          socket.puts 'probe'
          node_uuid = socket.gets&.chomp
        end
      rescue Timeout::Error => e
        @logger.warn("Failed to probe #{socket}")
        @logger.error(e.message.to_s)
        return nil
      end

      node_uuid
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
