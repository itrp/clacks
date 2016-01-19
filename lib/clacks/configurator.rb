# -*- encoding: binary -*-
module Clacks
  class Configurator
    require 'logger'
    attr_accessor :map, :config_file

    DEFAULTS = {
      :poll_interval => 60,
      :logger => Logger.new($stderr),
      :on_mail => lambda { |mail|
        Clacks.logger.info("Mail from #{mail.from.first}, subject: #{mail.subject}")
      }
    }

    def initialize(config_file = nil)
      self.map = Hash.new
      map.merge!(DEFAULTS)
      self.config_file = config_file
      instance_eval(File.read(config_file), config_file) if config_file
    end

    def [](key) # :nodoc:
      map[key]
    end

    def poll_interval(value)
      map[:poll_interval] = value.to_i
    end

    def pid(path)
      set_path(:pid, path)
    end

    # Sets the Logger-like object.
    # The default Logger will log its output to Rails.logger if
    # you're running within a rails environment, otherwise it will
    # output to the path specified by +stdout_path+.
    def logger(obj)
      %w(debug info warn error fatal level).each do |m|
        next if obj.respond_to?(m)
        raise ArgumentError, "logger #{obj} does not respond to method #{m}"
      end
      map[:logger] = obj
    end

    # If you're running Clacks daemonized, then you must specify a path
    # to prevent error messages from going to /dev/null.
    def stdout_path(path)
      set_path(:stdout_path, path)
    end

    # If you're running Clacks daemonized, then you must specify a path
    # to prevent error messages from going to /dev/null.
    def stderr_path(path)
      set_path(:stderr_path, path)
    end

    def pop3(hash)
      set_hash(:pop3, hash)
    end

    def imap(hash)
      set_hash(:imap, hash)
    end

    def find_options(hash)
      set_hash(:find_options, hash)
    end

    def on_mail(*args, &block)
      set_hook(:on_mail, 1, block_given? ? block : args[0])
    end

    def after_initialize(*args, &block)
      set_hook(:after_initialize, 0, block_given? ? block : args[0])
    end

    private

      def set_path(var, path) #:nodoc:
        raise ArgumentError unless path.nil? || path.is_a?(String)
        map[var] = path ? ::File.expand_path(path) : nil
      end

      def set_hash(var, hash) #:nodoc:
        raise ArgumentError unless hash.is_a?(Hash)
        map[var] = hash
      end

      def set_hook(var, expected_arity, proc) #:nodoc:
        raise ArgumentError unless proc.is_a?(Proc)
        unless proc.arity == expected_arity
          raise ArgumentError, "#{var}=#{proc.inspect} has invalid arity: #{proc.arity} (need #{expected_arity})"
        end
        map[var] = proc
      end

  end
end
