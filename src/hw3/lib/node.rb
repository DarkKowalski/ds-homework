# frozen_string_literal: true

require 'bundler'
Bundler.require
Dir[File.dirname(__FILE__) + '/node/*.rb'].sort.each { |file| require file }
