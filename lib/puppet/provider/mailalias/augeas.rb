# Alternative Augeas-based providers for Puppet
#
# Copyright (c) 2012 Dominic Cleal
# Licensed under the Apache License, Version 2.0

require 'augeas' if Puppet.features.augeas?

Puppet::Type.type(:mailalias).provide(:augeas) do
  desc "Uses Augeas API to update mail aliases file"

  confine :true   => Puppet.features.augeas? 
  confine :exists => "/etc/aliases"

  def self.file(resource = nil)
    file = "/etc/aliases"
    file = resource[:target] if resource and resource[:target]
    file.chomp("/")
  end

  def self.augopen(resource = nil)
    aug = nil
    file = file(resource)
    begin
      aug = Augeas.open(nil, nil, Augeas::NO_MODL_AUTOLOAD)
      aug.transform(
        :lens => "Aliases.lns",
        :name => "Aliases",
        :incl => file
      )
      aug.load!

      if aug.match("/files#{file}").empty?
        message = aug.get("/augeas/files#{file}/error/message")
        fail("Augeas didn't load #{file}: #{message}")
      end
    rescue
      aug.close if aug
      raise
    end
    aug
  end

  def self.instances
    aug = nil
    path = "/files#{file}"
    begin
      resources = []
      aug = augopen
      aug.match("#{path}/*").each do |apath|
        malias = {}
        malias[:name] = aug.get("#{apath}/name")
        next unless malias[:name]

        rcpts = []
        aug.match("#{apath}/value").each do |rcpt|
          rcpts << aug.get(rcpt)
        end
        malias[:recipient] = rcpts

        resources << new(malias)
      end
      resources
    ensure
      aug.close if aug
    end
  end

  def exists? 
    aug = nil
    path = "/files#{self.class.file(resource)}"
    begin
      aug = self.class.augopen(resource)
      not aug.match("#{path}/*[name = '#{resource[:name]}']").empty?
    ensure
      aug.close if aug
    end
  end

  def create 
    aug = nil
    path = "/files#{self.class.file(resource)}"
    begin
      aug = self.class.augopen(resource)
      aug.set("#{path}/01/name", resource[:name])

      resource[:recipient].each do |rcpt|
        aug.set("#{path}/01/value[last()+1]", rcpt)
      end

      aug.save!
    ensure
      aug.close if aug
    end
  end

  def destroy
    aug = nil
    path = "/files#{self.class.file(resource)}"
    begin
      aug = self.class.augopen(resource)
      aug.rm("#{path}/*[name = '#{resource[:name]}']")
      aug.save!
    ensure
      aug.close if aug
    end
  end

  def target
    self.class.file(resource)
  end

  def recipient
    aug = nil
    path = "/files#{self.class.file(resource)}"
    begin
      aug = self.class.augopen(resource)
      aliases = []
      aug.match("#{path}/*[name = '#{resource[:name]}']/value").each do |apath|
        aliases << aug.get(apath)
      end
      aliases
    ensure
      aug.close if aug
    end
  end

  def recipient=(values)
    aug = nil
    path = "/files#{self.class.file(resource)}"
    entry = "#{path}/*[name = '#{resource[:name]}']"
    begin
      aug = self.class.augopen(resource)
      aug.rm("#{entry}/value")

      values.each do |rcpt|
        aug.set("#{entry}/value[last()+1]", rcpt)
      end

      aug.save!
    ensure
      aug.close if aug
    end
  end
end