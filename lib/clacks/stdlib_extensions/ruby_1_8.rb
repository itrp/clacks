# -*- encoding: binary -*-
# Backport from ruby 1.9.3 source to ruby 1.8.7
class Net::IMAP
  def idle(&response_handler)
    raise LocalJumpError, "no block given" unless response_handler

    response = nil

    synchronize do
      tag = Thread.current[:net_imap_tag] = generate_tag
      put_string("#{tag} IDLE#{CRLF}")

      begin
        add_response_handler(response_handler)
        @idle_done_cond = new_cond
        @idle_done_cond.wait
        @idle_done_cond = nil
        if @receiver_thread_terminating
          raise Net::IMAP::Error, "connection closed"
        end
      ensure
        unless @receiver_thread_terminating
          remove_response_handler(response_handler)
          put_string("DONE#{CRLF}")
          response = get_tagged_response(tag)  #, "IDLE")
        end
      end
    end

    return response
  end

  def idle_done
    synchronize do
      if @idle_done_cond.nil?
        raise Net::IMAP::Error, "not during IDLE"
      end
      @idle_done_cond.signal
    end
  end
end
