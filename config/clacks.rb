# Configuration of clacks
# See Clacks::Configurator for documentation on options

poll_interval 20

if defined?(Rails) && Rails.env.development?
  pid "tmp/pids/clacks.pid"
  stdout_path 'log/clacks.log'
  stderr_path 'log/clacks.log'
else
  pid "/var/run/clacks.pid"
  stdout_path '/var/log/clacks.stdout.log'
  stderr_path '/var/log/clacks.stderr.log'
end

imap({
  :address    => "imap.googlemail.com",
  :port       => 993,
  :user_name  => '<user_name>'
  :password   => '<password>'
  :enable_ssl => true,
})

find_options({
  :mailbox => 'INBOX',
  :archivebox => '[Gmail]/All Mail',
  :delete_after_find => true
})

on_mail do |mail|
  Clacks.logger.info "Got new mail from #{mail.from.first}, subject: #{mail.subject}"
end
