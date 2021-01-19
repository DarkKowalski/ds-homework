# frozen_string_literal: true

require 'socket'
require 'json'
require 'timeout'

module Node
  module Gossip
    class AliveList
      attr_accessor :all_nodes
      def initialize
        @all_nodes = Set.new
      end

      def insert(node)
        @all_nodes.delete_if { |n| n['uuid'] == node['uuid'] }
        @all_nodes.add(node)
        Node.logger.debug("Update AliveList: uuid #{node['uuid']} time #{node['timestamp']}")
      end

      def remove(uuid)
        @all_nodes.delete_if { |n| n['uuid'] == uuid }
      end
    end

    class GossipServer
      def initialize(config = Node.config)
        seed = "#{config.service_host}:#{config.service_port}"
        @uuid = Digest::SHA256.hexdigest(seed)

        @self_info = { uuid: @uuid,
                       service_host: config.service_host,
                       service_port: config.service_port,
                       gossip_port: config.gossip_port,
                       timestamp: Time.now.to_i }

        @alive_list = AliveList.new

        @socket = UDPSocket.new
        @socket.bind(config.service_host.to_s, config.gossip_port.to_i)

        Node.logger.debug("Initialize GossipServer: host #{config.service_host}, port #{config.gossip_port}")
      end

      def gossip
        Node.logger.debug("AliveList: #{@alive_list.all_nodes.to_a}")
        # Clean up dead nodes
        @self_info['timestamp'] = Time.now.to_i
        @alive_list.all_nodes.each do |n|
          if @self_info['timestamp'] - n['timestamp'].to_i > 120
            @alive_list.remove(n['uuid'])
            Node.logger.info("Remove a dead node: uuid #{n['uuid']}")
          end
        end

        # Broadcast
        @alive_list.all_nodes.each do |n|
          socket = UDPSocket.new
          socket.connect(n['service_host'], n['gossip_port'].to_i)
          with_self = @alive_list.all_nodes.to_a + [@self_info]
          msg = { method: 'beat', info: with_self }.to_json
          socket.send(msg, 0)
        end

        # Listen
        begin
          status = Timeout.timeout(3) do
            recv_msg, recv_addr = @socket.recvfrom(4096)
            Node.logger.debug("Receive a new message: #{recv_msg} from #{recv_addr}")
            recv_msg = JSON.parse(recv_msg)
            if recv_msg['method'] == 'beat' || recv_msg['method'] == 'intro'
              nodes = recv_msg['info']
              nodes.each do |n|
                if n['uuid'] == @uuid # ignore self
                  Node.logger.debug('Ignore self')
                  next
                end

                @alive_list.insert(n)
                Node.logger.debug("Add a Node to AliveList: uuid #{n['uuid']}, timestamp #{n['timestamp']}")
              end
            elsif recv_msg['method'] == 'leave'
              uuid = recv_msg['info']
              @alive_list.remove(uuid)
              Node.logger.debug("Remove a Node from AliveList: uuid #{uuid}")
            end
          end
        rescue StandardError
          Node.logger.debug('Drain UDP buffer')
        end
      end

      def join(config = Node.config)
        socket = UDPSocket.new
        socket.connect(config.gossip_introducer_host, config.gossip_introducer_port)
        msg = { method: 'join', info: @self_info }.to_json
        socket.send(msg, 0)
      end

      def leave
        @alive_list.all_nodes.each do |n|
          socket = UDPSocket.new
          socket.connect(n['service_host'], n['gossip_port'].to_i.to_i)
          msg = { method: 'leave', info: @uuid }.to_json
          socket.send(msg, 0)
        end
      end

      def introduce
        loop do
          recv_msg, recv_addr = @socket.recvfrom(4096)
          recv_msg = JSON.parse(recv_msg)
          if recv_msg['method'] == 'join'
            node = recv_msg['info']
            @alive_list.insert(node)
            Node.logger.debug("Introduce: uuid #{node['uuid']}")
            Node.logger.debug("AliveList: #{@alive_list.all_nodes.to_a}")
          end

          @alive_list.all_nodes.each do |n|
            socket = UDPSocket.new
            socket.connect(n['service_host'], n['gossip_port'].to_i)
            msg = { method: 'intro', info: @alive_list.all_nodes.to_a }.to_json
            socket.send(msg, 0)
          end
        end
      end

      def serve
        join
        loop do
          gossip
          sleep(20)
        end
      end
    end
  end
end

module Node
  include Node::Gossip
end
