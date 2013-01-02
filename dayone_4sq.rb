#!/usr/bin/env ruby

require 'open-uri'
require 'open3'
require 'date'
require 'ri_cal'

class Importer
  attr_reader :url

  def initialize(token)
    @url = "https://feeds.foursquare.com/history/#{token}.ics" # get from https://foursquare.com/feeds/
    @new_last_id = 0
    restore_last_id
  end

  def storage_path
    "#{ENV['HOME']}/.dayone"
  end

  def last_id_path
    "#{storage_path}/4sq_last_id.txt"
  end

  def restore_last_id
    begin
      @last_id = File.read(last_id_path).to_i
    rescue Errno::ENOENT => e
      @last_id = 0
    end
  end

  def save_last_id
    if @new_last_id > 0
      File.open(last_id_path, 'w') do |file|
        file.write @new_last_id
      end
    end
  end

  def import
    begin
      do_import
    rescue Done
    rescue OpenURI::HTTPError => e
      puts e
    end
    save_last_id
  end

  def do_import
    uri = URI.parse @url
    cal = RiCal.parse_string uri.read
    cal.first.events.each do |event|
      handle_checkin Checkin.new(event)
    end
  end

  def handle_checkin(checkin)
    @new_last_id = [ @new_last_id, checkin.id ].max
    if checkin.id <= @last_id
      raise Done
    end
    Open3.popen3('dayone', "-d=#{checkin.time}", 'new') do |stdin, stdout, stderr|
      stdin.write("@ " + checkin.venue + " via " + checkin.url)
      stdin.close_write
      puts stdout.read
    end
  end
end

class Done < Exception; end

class Checkin
  def initialize(event)
    @event = event
  end

  def id
    @event.dtstart.to_time.to_i
  end

  def url
    @event.url
  end

  def venue
    @event.location
  end

  def time
    @event.dtstart.to_time.to_s
  end
end

Importer.new(*ARGV).import
