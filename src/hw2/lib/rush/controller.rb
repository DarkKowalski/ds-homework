# frozen_string_literal: true

require 'socket'
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

    def probe_node(ip, port)
      @logger.debug("Probe Node #{ip}:#{port}")

      socket = create_socket(ip, port)
      return if socket.nil?

      socket.puts 'probe'
      node_uuid = socket.gets&.chomp

      if node_uuid.nil?
        @logger.warn("Failed to probe #{ip}:#{port}")
        return nil
      end

      socket.close
      node_uuid
    end

    def add_node(ip, port)
      uuid = probe_node(ip, port)
      return if uuid.nil?

      if @nodes.key?(uuid)
        @logger.warn("Duplicated Node #{uuid}")
        return
      end

      @nodes[uuid] = [ip, port]
      @logger.debug("Add Node #{uuid}, ip = #{ip}, port = #{port}")
    end

    def remove_node(uuid)
      @nodes.delete(uuid)
      @logger.debug("Remove Node #{uuid}")
    end

    def connect_node(uuid)
      ip, port = @nodes[uuid]
      socket = create_socket(ip, port)
      return if socket.nil?

      @sockets[uuid] = socket
      @logger.debug("Connect to Node #{uuid}, ip = #{ip}, port = #{port}")
    end

    def disconnect_node(uuid)
      @sockets[uuid].close
      @sockets.delete(uuid)
      @logger.debug("Disconnect from Node #{uuid}")
    end

    # Connect to all nodes
    def connect
      @nodes.each_key { |uuid| connect_node(uuid) }
    end

    # Disconnect from all nodes
    def disconnect
      @nodes.each_key { |uuid| disconnect_node(uuid) }
    end
  end
end
