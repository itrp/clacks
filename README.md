# Clacks

[![Build Status](https://secure.travis-ci.org/itrp/clacks.png)](http://travis-ci.org/itrp/clacks?branch=master)
[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/itrp/clacks)
[![Gem Version](https://fury-badge.herokuapp.com/rb/clacks.png)](http://badge.fury.io/rb/clacks)

"The clacks is a system of shutter semaphore towers which occupies roughly the same cultural space as telegraphy in nineteenth century Europe." ^[[1]](http://en.wikipedia.org/wiki/Technology_of_the_Discworld#The_clacks)

Clacks is an easy way to process incoming emails in ruby. It uses the POP3 or IMAP protocol. If the IMAP protocol is used and the IMAP server advertises the [IDLE](http://tools.ietf.org/rfc/rfc2177.txt) capability it will use that. Which means that emails are pushed to your email processor instead of having to poll for it at regular intervals, which in turn means emails arrive near real-time at your systems.

Clacks can be used standalone and/or within a Rails environment.


Installation and Usage
----------------------

If you use Rails, add this to your Gemfile:

    gem 'clacks', :require => nil

Then create a configuration file, using ruby syntax, such as:

``` ruby
# Configuration of clacks
# See Clacks::Configurator for documentation on options
#
# Put this in: <RAILS_ROOT>/config/clacks.rb
#

poll_interval 30
pid "tmp/pids/clacks.pid"
stdout_path 'log/clacks.log'
stderr_path 'log/clacks.log'

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

  to = mail.to.first
  if to =~ /^task-(\d+)@example.com/
    Task.find($1).add_note(mail)
  elsif to =~ /^(\w+)@example.com/
    Account.find_by_name($1).tickets.create_from_mail!(mail)
  else
    # Prevent deletion of this mail after all
    mail.skip_deletion
  end
end
```

See [Clacks::Configurator](https://github.com/itrp/clacks/tree/master/lib/clacks/configurator.rb) for documentation on all options.

Start clacks:

```
/project/my_rails_app$ clacks --help
/project/my_rails_app$ clacks
```

Clacks can run as a daemon:

```
/project/my_rails_app$ clacks -D
```

Once it's running as a daemon process you can control it via sending signals. See the available signals below.

See the [contrib](https://github.com/itrp/clacks/tree/master/contrib/) directory for handy init.d, logrotate and monit scripts.


Signals
-------

* KILL - quick shutdown, kills the process immediately.

* TERM/QUIT/INT - graceful shutdown, waits for the worker process to finish processing an email.

* USR1 - reopen logs


Copyright
-----------

Copyright (c) 2013-2016 ITRP. See MIT-LICENSE for details.
