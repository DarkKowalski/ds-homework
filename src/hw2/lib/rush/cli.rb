# frozen_string_literal: true

require 'optparse'

module Rush
  class Cli
    def initialize(logger = Rush.logger)
      @logger = logger
      @logger.level = 'warn'

      @options = {}
      @parser = OptionParser.new do |opts|
        opts.banner = 'Usage: rush [options]'
        opts.on('-s', '--split [FILE]', "Split dblp.xml into #{Rush::PG::ALL_PG} files", String) do |v|
          @options[:mode] = :split
          @options[:file] = v
        end

        opts.on('-d', '--debug', 'Set logging level to debug', String) do
          @logger.level = 'debug'
        end
      end
    end

    def start
      @parser.parse!
      case @options[:mode]
      when :split
        xml = @options[:file]
        Rush::Parser.new.open(xml).split
      else
        puts @parser
      end
    end
  end
end
