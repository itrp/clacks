module Clacks
  require 'clacks/version'
  require 'clacks/configurator'
  require 'clacks/command'
  require 'clacks/service'

  def self.config=(config)
    @config = config
  end

  def self.config
    @config ||= Clacks::Configurator.new
  end

  def self.logger
    @logger ||= Clacks.config[:logger]
  end

  RAILS_CONFIG_ENV = 'config/environment.rb'
  def self.rails_env?
    @rails_env ||= defined?(Rails) || File.readable?(RAILS_CONFIG_ENV)
  end

  def self.require_rails
    ENV['RAILS_ENV'] ||= 'development'
    require "#{Dir.pwd}/#{RAILS_CONFIG_ENV}" unless defined?(Rails)
  end
end

