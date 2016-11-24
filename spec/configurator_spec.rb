require 'spec_helper'
require 'tempfile'

describe Clacks::Configurator do

  it "has defaults" do
    config = Clacks::Configurator.new
    expect(config[:poll_interval]).to eq(60)
    expect(config[:pid]).to be_nil
    expect(config[:stdout_path]).to be_nil
    expect(config[:stderr_path]).to be_nil
    config[:on_mail].call(Mail.new(from: 'foo@example.com', subject: 'foo'))
    last_log_line = `tail -n 1 /tmp/clacks.log`
    expect(last_log_line).to include('Mail from foo@example.com, subject: foo')
  end

  it "has invalid config" do
    tmp = Tempfile.new('clacks.config')
    tmp.syswrite(%[foo "hello-world"])
    expect { Clacks::Configurator.new(tmp.path) }.to raise_error(NoMethodError)
  end

  it "has non-existent config" do
    tmp = Tempfile.new('clacks.config')
    path = tmp.path
    tmp.close!
    expect { Clacks::Configurator.new(path) }.to raise_error(Errno::ENOENT)
  end

  context 'on_mail proc' do
    it "should test for arity of the on_mail proc" do
      tmp = Tempfile.new('clacks.config')
      tmp.syswrite(%[on_mail{|x,y|x+y}])
      expect { Clacks::Configurator.new(tmp.path) }.to raise_error(ArgumentError, /on_mail=.* has invalid arity: 2 \(need 1\)/)
    end

    it "should configure the on_mail hook" do
      tmp = Tempfile.new('clacks.config')
      tmp.syswrite(%[on_mail{|mail|mail+1}])
      expect(Clacks::Configurator.new(tmp.path)[:on_mail].call(5)).to eq(6)
    end
  end

  context 'after_initialize proc' do
    it "should test for arity of the after_initialize proc" do
      tmp = Tempfile.new('clacks.config')
      tmp.syswrite(%[after_initialize{|x,y|x+y}])
      expect { Clacks::Configurator.new(tmp.path) }.to raise_error(ArgumentError, /after_initialize=.* has invalid arity: 2 \(need 0\)/)
    end

    it "should configure the after_initialize hook" do
      tmp = Tempfile.new('clacks.config')
      tmp.syswrite(%[after_initialize { 42 }])
      expect(Clacks::Configurator.new(tmp.path)[:after_initialize].call).to eq(42)
    end
  end

end
