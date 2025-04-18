#!/usr/bin/env ruby
require "shellwords"
require "fileutils"
require "open3"
require "thread"

selected_path =
if File.exist?("/home/mit/Source/trompie")
  "/home/mit/Source/trompie/lib"
else
  "/etc/nixos/res/gems/trompie/lib"
end

$LOAD_PATH.unshift(selected_path)
puts " > trompie lib #{selected_path}"

require "trompie"

module YTDLTT

  include Trompie

  TOPIC = "yt/dl"

  #mqtt = MMQTT.new
  # ha = HA.new

  class YTDLWrapper
    attr_reader :data

    DEFAULTS ={
      variant: :audio,
      videoIncoming: "/home/media/youtube",
      audioIncoming: "/home/media/youtube"
    }

    attr_accessor *DEFAULTS.keys
    attr_accessor :config

    module Dataset
      def nrmlz
        keys.each do |k|
          if k.is_a?(String)
            self[k.to_sym] = delete(k)
          end
        end 
        self 
      end
    end

    # entrypoint
    def YTDLWrapper.[](inputdata, config: DEFAULTS)
      Downloader.new(select_from_datasat(inputdata.extend(Dataset).nrmlz, config))
    end


    # get handler class from input hash
    def self.select_from_datasat(inputdata, config)
      data = inputdata.dup
      url = data.delete(:url)

      # add default prefix when not set
      unless url =~ /^[AV]---/
        prefix = config[:variant] == :audio ? "A" : "V"
        url = "#{prefix}---#{url}"
      end

      if url =~ /^([AV])---(.+)$/
        type = $1
        data[:url] = URI($2).to_s
        return (type.to_s.downcase == "a" ? Audio : Video).new(data, config)
      else
        raise ArgumentError, "Invalid URL format: #{url.inspect}"
      end
    end

    def initialize(data, config)
      @config = config
      @data = data
    end

    def data_field(which)
      data[which.to_sym]
    end

    def url
      data_field(:url)
    end

    def title_template
      @title_template ||= '%(title).200s-%(id)s.%(ext)s'
    end

    def ytdlp_default_arguments(*args)
      [ '-o', title_template, '--restrict-filenames',
        '--no-playlist', '--no-post-overwrites', '--no-mtime', '--no-write-comments' ] + args
    end

    def full_arguments
      [ytdlp_default_arguments, user_arguments, url].flatten
    end

    def user_arguments
      user_parameters = Array(@data['parameters'])
      unless user_parameters.any?{ |up| "-P" }
        tdir = config[:videoIncoming]
        tmp = target_directory + "/.tmp"
        FileUtils.mkdir_p(target_directory, verbose: true)
        user_parameters.push("-P", "temp:%s" % [tmp])
        user_parameters.push("-P", "home:%s" % [target_directory])
      end
      user_parameters
    end
  end

  class Audio < YTDLWrapper
    def ytdlp_default_arguments
      super '-f bestaudio', '--extract-audio', '--audio-format mp3', '--audio-quality 0'
    end

    def target_directory
      config[:audioIncoming]
    end
  end

  class Video < YTDLWrapper
    def ytdlp_default_arguments
      super '-f bestvideo+bestaudio/best', '--merge-output-format mp4'
    end
    
    def target_directory
      config[:videoIncoming]
    end
  end

  class Downloader

    include Trompie

    attr_reader :media
    attr_accessor :mqtt

    def initialize(wrapperinst)
      @media = wrapperinst
    end

    def self.queue
      @queue ||= Queue.new
    end

    def self.mqtt
      @mqtt ||= MMQTT.new
    end

    def self.loop!
      thread!
      mqtt.subscribe(TOPIC) do |data|
        Trompie.debug { Trompie.log "Enqueuing job: #{data.inspect}" }
        Downloader.queue << data
      end
    end

    def self.thread!
      Thread.new do
        loop do
          data = Downloader.queue.pop
          begin
            ytdlwr = YTDLTT::YTDLWrapper[data]
            Trompie.log "%s: %s" % [ytdlwr.media.class, ytdlwr.media.url]
            ytdlwr.download
          rescue => e
            Trompie.error "Download failed: #{e.class} - #{e.message}"
          end
        end
      end
    end

    def command
      [bin, @media.full_arguments].flatten.map { |p| Shellwords.split(p) }.flatten
    end
    
    def bin
      "yt-dlp"
    end

    def download(&blk)
      old_stdoutsync = $stdout.sync
      $stdout.sync = true

      run_download_command

      yield self if block_given?

      $stdout.sync = old_stdoutsync
      true
    end

    def run_download_command
      $stdout.sync = true

      Trompie.debug { log "Arguments: "+ PP.pp(command.unshift, "").gsub(/\n/, "") }

      Open3.popen2e(*command) do |stdin, stdout_and_err, wait_thr|
        stdout_and_err.each_line do |line|
          log line
        end

        exit_status = wait_thr.value
        unless exit_status.success?
          return false
        end
      end
      true
    end
  end

  if __FILE__ == $0
    Downloader.loop!
  end
end

