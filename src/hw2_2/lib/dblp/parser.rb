# frozen_string_literal: true

require 'fileutils'
require 'nokogiri'
require 'json'

module DBLP
  class Parser
    def initialize(logger = DBLP.logger)
      @logger = logger
      @logger.debug 'Initialize Parser'
    end

    def open(filepath)
      @doc = Nokogiri::XML(File.open(filepath))
      @logger.debug "Import #{filepath} to Nokogiri"

      self
    end

    def articles
      @doc.xpath('//article')
    end

    def split
      FileUtils.mkdir_p 'split'
      articles.each do |article|
        rand = Random.new.rand(0...DBLP::SPLIT_NUM)

        path = File.join('split', "#{rand}.xml")
        unless File.file?(path)
          File.open(path, 'w') do |f|
            f.puts '<dblp>'
          end
        end

        File.open(path, 'a') do |f|
          f.puts article
        end
      end

      Dir.entries('split').each do |e|
        path = File.join('split', e)
        next unless File.file?(path)

        File.open(path, 'a') do |f|
          f.puts '</dblp>'
        end
      end
    end
  end
end
