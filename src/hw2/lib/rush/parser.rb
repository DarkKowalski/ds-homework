# frozen_string_literal: true

require 'fileutils'
require 'nokogiri'

module Rush
  class Parser
    def initialize(logger = Rush.logger)
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

    def authors
      authors = Hash.new { |hash, key| hash[key] = [] }
      articles.each do |article|
        title = article.at_xpath('title').content
        @logger.debug "Article title: #{title}"
        article.xpath('author').each do |authour|
          name = authour.content.to_s
          authors[name].push(title)
          @logger.debug(" | Author name: #{name}")
        end
      end
      @logger.debug "Total #{authors.size} authors"
      authors
    end

    def split(dirpath = 'authors')
      FileUtils.mkdir_p(dirpath)
      authors.each do |name, articles|
        id = Rush::FileId.hex(name)
        filename = "#{id}.txt"
        path = File.join(dirpath, filename)
        File.open(path, 'w') do |f|
          f.puts "# Author: #{name}"
          f.puts "# Articles: #{articles.size}"
          articles.each { |article| f.puts article }
        end
        @logger.debug "Store #{name} as #{filename}"
      end
    end
  end
end
