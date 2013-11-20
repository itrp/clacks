# -*- encoding: binary -*-
require 'spec_helper'

describe Clacks::Service do

  it "should ensure utf7 conversion for mailbox names" do
    Mail::IMAP.new({})
    Net::IMAP.stub(:encode_utf7).with('INBOX') { 'UTF7_INBOX' }
    Net::IMAP.stub(:encode_utf7).with('ARCHIVE') { 'ARCHIVE_INBOX' }
    options = Clacks::Service.new.send(:imap_validate_options, {
      :mailbox => 'INBOX',
      :archivebox => 'ARCHIVE'
    })
    options[:mailbox].should == 'UTF7_INBOX'
    options[:archivebox].should == 'ARCHIVE_INBOX'
  end

end