# frozen_string_literal: true

require 'fileutils'
require 'nokogiri'
require 'json'

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
      placeholder(dirpath)
      pg = Array.new(Rush::ALL_PG) { [] }
      authors.each do |name, articles|
        file_id = Rush::FileId.hex(name)
        pg_id = Rush::PG.id(file_id)
        hash = { id: file_id, name: name, article_num: articles.size, articles: articles }
        pg[pg_id].push(hash)
        @logger.debug("Put #{hash} into PG #{pg_id}")
      end

      each_pg_file do |pg_id, path|
        json = JSON.pretty_generate(pg[pg_id])
        File.open(path, 'w') { |f| f.puts json }
        @logger.debug("Write #{path}")
      end
    end

    private

    def each_pg_file(dirpath = 'authors')
      Rush::ALL_PG.times do |pg_id|
        filename = "#{pg_id}.json"
        path = File.join(dirpath, filename)
        yield(pg_id, path)
      end
    end

    def placeholder(dirpath = 'authors')
      # Generate placeholders
      FileUtils.mkdir_p(dirpath)
      each_pg_file { |_pg_id, path| FileUtils.touch path }
    end
  end
end
