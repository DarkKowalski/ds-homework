# frozen_string_literal: true

require 'optparse'

module DBLP
  class Cli
    def initialize(logger = DBLP.logger)
      @logger = logger
      @logger.level = 'warn'

      @options = {}
      @parser = OptionParser.new do |opts|
        opts.banner = 'Usage: DBLP [options]'
        opts.on('-s', '--split [FILE]', "Split dblp.xml into #{DBLP::SPLIT_NUM} files", String) do |v|
          @options[:mode] = :split
          @options[:file] = v
        end

        opts.on('-c', '--controller', 'Run as the controller', String) do
          @options[:mode] = :controller
        end

        opts.on('-n', '--node [PORT]', 'Run as the node', String) do |v|
          @options[:mode] = :node
          @options[:port] = v
        end

        opts.on('-u', '--uuid [UUID]', 'Set node UUID', String) do |v|
          @options[:mode] = :node
          @options[:uuid] = v
        end

        opts.on('-d', '--debug', 'Set logging level to debug', String) do
          @logger.level = 'debug'
        end
      end
    end

    def start
      @parser.parse!
      case @options[:mode]
      when :controller
        DBLP::Controller.new.start
      when :node
        uuid = @options[:uuid]
        port = @options[:port]
        return if uuid.nil? || port.nil?

        DBLP::Node.new(uuid, port).listen
      when :split
        xml = @options[:file]
        DBLP::Parser.new.open(xml).split
      else
        puts @parser
      end
    end
  end
end
