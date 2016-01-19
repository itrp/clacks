# -*- encoding: binary -*-
module Clacks
  class Command
    require 'optparse'

    PROC_NAME = ::File.basename($0.dup)
    PROC_ARGV = ARGV.map { |a| a.dup }

    def initialize(args)
      @options = { :config_file => "config/clacks.rb" }

      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{PROC_NAME} [options]"

        if Clacks.rails_env?
          opts.separator "Rails options:"
          opts.on("-E", "--env RAILS_ENV", "use RAILS_ENV for defaults (default: development)") do |e|
            ENV['RAILS_ENV'] = e
          end
        end

        opts.separator "Ruby options:"

        opts.on("-d", "--debug", "set debugging flags (set $DEBUG to true)") do
          $DEBUG = true
        end

        opts.on("-w", "--warn", "turn warnings on for your script") do
          $-w = true
        end

        opts.separator "Clacks options:"

        opts.on("-c", "--config-file FILE", "Clacks-specific config file (default: #{@options[:config_file]})") do |f|
          @options[:config_file] = f
        end

        opts.on("-D", "--daemonize", "run daemonized in the background") do |d|
          @options[:daemonize] = !!d
        end

        opts.on("-P", "--pid FILE", "file to store PID (default: clacks.pid)") { |f|
          @options[:pid] = f
        }

        opts.separator "Common options:"

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts.to_s.gsub(/^.*DEPRECATED.*$/s, '')
          exit
        end

        opts.on_tail("-v", "--version", "Show version") do
          puts "#{PROC_NAME} v#{Clacks::VERSION}"
          exit
        end
      end
      @args = opts.parse!(args)
    end

    def exec
      daemonize if @options[:daemonize]

      Clacks.require_rails if Clacks.rails_env?

      Clacks.config = config = Clacks::Configurator.new(@options[:config_file])
      unless config[:pop3] || config[:imap]
        $stderr.puts "Either a POP3 or an IMAP server must be configured"
        exit!(1)
      end

      reopen_io($stdout, config[:stdout_path])
      reopen_io($stderr, config[:stderr_path])

      unless config[:pid]
        config.pid(@options[:pid] || (defined?(Rails) && Rails.version =~ /^2/ ? 'tmp/pids/clacks.pid' : 'clacks.pid'))
      end
      pid = config[:pid]
      if wpid = running?(pid)
        $stderr.puts "#{Clacks::Command::PROC_NAME} already running with pid: #{wpid} (or stale #{pid})"
        exit!(1)
      end
      write_pid(pid)

      config[:after_initialize].call if config[:after_initialize]

      proc_name('master')

      setup_signal_handling

      @service = Clacks::Service.new
      @service.run
    end

    private

    # See Stevens's "Advanced Programming in the UNIX Environment" chapter 13
    def daemonize(safe = true)
      $stdin.reopen '/dev/null'

      # Fork and have the parent exit.
      # This makes the shell or boot script think the command is done.
      # Also, the child process is guaranteed not to be a process group
      # leader (a prerequisite for setsid next)
      exit if fork

      # Call setsid to create a new session. This does three things:
      # - The process becomes a session leader of a new session
      # - The process becomes the process group leader of a new process group
      # - The process has no controlling terminal
      Process.setsid

      # Fork again and have the parent exit.
      # This guarantes that the daemon is not a session leader nor can
      # it acquire a controlling terminal (under SVR4)
      exit if fork

      unless safe
        ::Dir.chdir('/')
        ::File.umask(0000)
      end

      cfg_defaults = Clacks::Configurator::DEFAULTS
      cfg_defaults[:stdout_path] ||= "/dev/null"
      cfg_defaults[:stderr_path] ||= "/dev/null"
    end

    # Redirect file descriptors inherited from the parent.
    def reopen_io(io, path)
      io.reopen(::File.open(path, "ab")) if path
      io.sync = true
    end

    # Read the working pid from the pid file.
    def running?(path)
      wpid = ::File.read(path).to_i
      return if wpid <= 0
      Process.kill(0, wpid)
      wpid
    rescue Errno::EPERM, Errno::ESRCH, Errno::ENOENT
      # noop
    end

    # Write the pid.
    def write_pid(pid)
      ::File.open(pid, 'w') { |f| f.write("#{Process.pid}") }
      at_exit { ::File.delete(pid) if ::File.exist?(pid) rescue nil }
    end

    def proc_name(tag)
      $0 = [ Clacks::Command::PROC_NAME, tag, Clacks::Command::PROC_ARGV ].join(' ')
    end

    def setup_signal_handling
      stop_signal = (Signal.list.keys & ['QUIT', 'INT']).first
      Signal.trap(stop_signal) do
        Thread.new { Clacks.logger.info 'QUIT signal received. Shutting down gracefully.' }
        @service.stop if @service
      end unless stop_signal.nil?

      Signal.trap('USR1') do
        Thread.new { Clacks.logger.info 'USR1 signal received. Rotating logs.' }
        rotate_logs
      end if Signal.list['USR1']
    end

    def rotate_logs
      reopen_io($stdout, Clacks.config[:stdout_path])
      reopen_io($stderr, Clacks.config[:stderr_path])
    end

  end
end
