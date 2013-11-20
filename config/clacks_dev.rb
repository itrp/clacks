# Configuration of clacks

#poll_interval 20

# pid "/var/run/clacks.pid"
# stdout_path '/var/log/clacks.stdout.log'
# stderr_path '/var/log/clacks.stderr.log'

# To override rails:
# Configurator::DEFAULTS[:logger].formatter = Logger::Formatter.new
Configurator::DEFAULTS[:logger].level = Logger::DEBUG

# pid "/tmp/clacks.pid"
# stdout_path '/tmp/clacks.stdout.log'
# stderr_path '/tmp/clacks.stderr.log'

imap({
  :address             => "imap.googlemail.com",
  :port                => 993,
  :user_name           => 'development.mailbox@itrp-staging.com',  # <user_name>
  :password            => 'itrpd3v123',   # <password>
  :enable_ssl          => true,
})

find_options({
  :mailbox => 'INBOX',
  :archivebox => '[Gmail]/All Mail',
  :delete_after_find => true
})


# on_mail_header do |header|
#   Clacks.logger.info "Got new mail header: from #{mail.from.first}, subject: #{mail.subject}"
# end

on_mail do |mail|
  Clacks.logger.info "Got new mail from #{mail.from.first}, subject: #{mail.subject}"
end
