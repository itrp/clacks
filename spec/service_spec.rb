require 'spec_helper'

describe Clacks::Service do

  it "should ensure utf7 conversion for mailbox names" do
    Mail::IMAP.new({})
    allow(Net::IMAP).to receive(:encode_utf7).with('INBOX').and_return('UTF7_INBOX')
    allow(Net::IMAP).to receive(:encode_utf7).with('ARCHIVE').and_return('ARCHIVE_INBOX')
    options = Clacks::Service.new.send(:imap_validate_options, {
      :mailbox => 'INBOX',
      :archivebox => 'ARCHIVE'
    })
    expect(options[:mailbox]).to eq('UTF7_INBOX')
    expect(options[:archivebox]).to eq('ARCHIVE_INBOX')
  end

end