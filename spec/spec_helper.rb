# -*- encoding: binary -*-
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
$LOAD_PATH.unshift File.dirname(__FILE__)

STDERR.puts("Running Specs under Ruby Version #{RUBY_VERSION}")

require 'rspec'
require 'clacks'

require 'logger'
Clacks.config.logger(Logger.new('/tmp/clacks.log'))

RSpec.configure do |c|
  c.mock_with :rspec
end

