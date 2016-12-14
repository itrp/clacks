module Clacks
  class Service
    # TODO: find the root cause and remove workaround below, @see http://stackoverflow.com/a/16007377/3774613
    begin require 'active_support'; rescue Exception => e; end

    require 'mail'

    # In practice timeouts occur when there is no activity keeping an IMAP connection open.
    # Timeouts occuring are:
    #   IMAP server timeout: typically after 30 minutes with no activity.
    #   NAT Gateway timeout: typically after 15 minutes with an idle connection.
    # The solution to this is for the IMAP client to issue a NOOP (No Operation) command
    # at intervals, typically every 12 minutes.
    WATCHDOG_SLEEP = 5 * 60   # 5 minutes

    def run
      begin
        Clacks.logger.info "Clacks v#{Clacks::VERSION} started"
        if Clacks.config[:pop3]
          run_pop3
        elsif Clacks.config[:imap]
          run_imap
        else
          raise "Either a POP3 or an IMAP server must be configured"
        end
      rescue Exception => e
        fatal(e)
      end
    end

    def stop
      $STOPPING = true
      exit unless finding?
    end

    private

    def fatal(e)
      unless e.is_a?(SystemExit) || e.is_a?(SignalException)
        Clacks.logger.fatal("#{e.message} (#{e.class})\n#{(e.backtrace || []).join("\n")}")
      end
      stop
      raise e
    end

    def run_pop3
      config = Clacks.config[:pop3]
      Clacks.logger.info("Clacks POP3 polling #{config[:user_name]}@#{config[:address]}")
      # TODO: if $DEBUG
      processor = Mail::IMAP.new(config)
      poll(processor)
    end

    def run_imap
      config = Clacks.config[:imap]
      options = Clacks.config[:find_options]
      processor = Mail::IMAP.new(config)
      require 'clacks/stdlib_extensions/ruby_1_8' if RUBY_VERSION.to_f < 1.9
      Net::IMAP.debug = $DEBUG
      imap_validate_options(options)
      if imap_idle_support?(processor)
        Clacks.logger.info("Clacks IMAP idling #{config[:user_name]}@#{config[:address]}")
        imap_idling(processor)
      else
        Clacks.logger.info("Clacks IMAP polling #{config[:user_name]}@#{config[:address]}")
        poll(processor)
      end
    end

    # Follows mostly the defaults from the Mail gem
    def imap_validate_options(options)
      options ||= {}
      options[:mailbox] ||= 'INBOX'
      options[:count]   ||= 5
      options[:order]   ||= :asc
      options[:what]    ||= :first
      options[:keys]    ||= 'ALL'
      options[:delete_after_find] ||= false
      options[:mailbox] = Net::IMAP.encode_utf7(options[:mailbox])
      if options[:archivebox]
        options[:archivebox] = Net::IMAP.encode_utf7(options[:archivebox])
      end
      options
    end

    def imap_idle_support?(processor)
      processor.connection { |imap| imap.capability.include?("IDLE") }
    end

    def imap_idling(processor)
      imap_watchdog
      loop do
        begin
          processor.connection do |imap|
            @imap = imap
            # select the mailbox to process
            imap.select(Clacks.config[:find_options][:mailbox])
            loop {
              break if stopping?
              finding { imap_find(imap) }
              # http://tools.ietf.org/rfc/rfc2177.txt
              imap.idle do |r|
                Clacks.logger.debug('imap.idle yields')
                if r.instance_of?(Net::IMAP::UntaggedResponse) && r.name == 'EXISTS'
                  imap.idle_done unless r.data == 0
                elsif r.instance_of?(Net::IMAP::ContinuationRequest)
                  Clacks.logger.info(r.data.text)
                end
              end
            }
          end
        rescue Net::IMAP::BadResponseError => e
          unless e.message == 'Could not parse command'
            Clacks.logger.error("#{e.message} (#{e.class})\n#{(e.backtrace || []).join("\n")}")
          end
          # reconnect in next loop
        rescue Net::IMAP::Error, IOError => e
          # OK: reconnect in next loop
        rescue Errno::ECONNRESET => e
          # Connection reset by peer: reconnect in next loop
        rescue StandardError => e
          Clacks.logger.error("#{e.message} (#{e.class})\n#{(e.backtrace || []).join("\n")}")
          sleep(5) unless stopping?
        end
        break if stopping?
      end
    end

    def imap_watchdog
      Thread.new do
        loop do
          begin
            Clacks.logger.debug('watchdog is sleeping')
            sleep(WATCHDOG_SLEEP)
            Clacks.logger.debug('watchdog is awake')
            @imap.idle_done
            Clacks.logger.debug('watchdog send idle done')
            @imap.noop
            Clacks.logger.debug('watchdog send noop')
          rescue StandardError => e
            Clacks.logger.debug("watchdog received error: #{e.message}")
            # noop
          rescue Exception => e
            fatal(e)
          end
        end
      end
    end

    # Keep processing emails until nothing is found anymore,
    # or until a QUIT signal is received to stop the process.
    def imap_find(imap)
      options = Clacks.config[:find_options]
      delete_after_find = options[:delete_after_find]
      begin
        break if stopping?
        uids = imap.uid_search(options[:keys] || 'ALL')
        uids.reverse! if options[:what].to_sym == :last
        uids = uids.first(options[:count]) if options[:count].is_a?(Integer)
        uids.reverse! if (options[:what].to_sym == :last && options[:order].to_sym == :asc) ||
                         (options[:what].to_sym != :last && options[:order].to_sym == :desc)
        processed = 0
        expunge = false
        uids.each do |uid|
          break if stopping?
          source = imap.uid_fetch(uid, ['RFC822']).first.attr['RFC822']
          mail = nil
          begin
            mail = Mail.new(source)
            mail.mark_for_delete = true if delete_after_find
            Clacks.config[:on_mail].call(mail)
          rescue StandardError => e
            Clacks.logger.error(e.message)
            Clacks.logger.error(e.backtrace)
          end
          begin
            imap.uid_copy(uid, options[:archivebox]) if options[:archivebox]
            if delete_after_find && (mail.nil? || mail.is_marked_for_delete?)
              expunge = true
              imap.uid_store(uid, "+FLAGS", [Net::IMAP::DELETED])
            end
          rescue StandardError => e
            Clacks.logger.error(e.message)
          end
          processed += 1
        end
        imap.expunge if expunge
      end while uids.any? && processed == uids.length
    end

    def poll(processor)
      polling_msg = if polling?
        "Clacks polling every #{poll_interval} seconds."
      else
        "Clacks polling for messages once."
      end
      Clacks.logger.info(polling_msg)

      find_options = Clacks.config[:find_options]
      on_mail = Clacks.config[:on_mail]
      loop do
        break if stopping?
        finding {
          processor.find(find_options) do |mail|
            if stopping?
              mail.skip_deletion
            else
              begin
                on_mail.call(mail)
              rescue StandardError => e
                Clacks.logger.error(e.message)
                Clacks.logger.error(e.backtrace)
              end
            end
          end
        }
        break if stopping? || !polling?
        sleep(poll_interval)
      end
    end

    def poll_interval
      Clacks.config[:poll_interval]
    end

    def polling?
      poll_interval > 0
    end

    def finding(&block)
      @finding = true
      yield
    ensure
      @finding = false
    end

    def finding?
      @finding
    end

    def stopping?
      $STOPPING
    end

    at_exit {
      Clacks.logger.info("Clacks stopped.") if $STOPPING
    }

  end
end