# frozen_string_literal: true

# frozen_string_literal: true

require 'bundler'
Bundler.require
Dir[File.dirname(__FILE__) + '/dblp/*.rb'].sort.each { |file| require file }
