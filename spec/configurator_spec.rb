# -*- encoding: binary -*-
require 'spec_helper'
require 'tempfile'

describe Clacks::Configurator do

  it "has defaults" do
    config = Clacks::Configurator.new
    config[:poll_interval].should == 60
    config[:pid].should be_nil
    config[:stdout_path].should be_nil
    config[:stderr_path].should be_nil
    config[:on_mail].call(Mail.new(:from => "foo@example.com", :subject => "foo"))
    last_log_line = `tail -n 1 /tmp/clacks.log`
    last_log_line.should =~ /Mail from foo@example.com, subject: foo/
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

  it "should test for arity of the on_mail proc" do
    tmp = Tempfile.new('clacks.config')
    tmp.syswrite(%[on_mail{|x,y|x+y}])
    expect { Clacks::Configurator.new(tmp.path) }.to raise_error(ArgumentError, /on_mail=.* has invalid arity: 2 \(need 1\)/)
  end

  it "should configure the on_mail hook" do
    tmp = Tempfile.new('clacks.config')
    tmp.syswrite(%[on_mail{|mail|mail+1}])
    Clacks::Configurator.new(tmp.path)[:on_mail].call(5).should == 6
  end

end
