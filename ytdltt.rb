#!/usr/bin/env ruby
require "shellwords"
require "fileutils"
require "open3"


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

  mqtt = MMQTT.new
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

    # entrypoint
    def YTDLWrapper.[](inputdata, config: DEFAULTS)
      Downloader.new(select_from_datasat(inputdata, config))
    end

    # normalizes url (which might be prefixed with A--- or V---) and
    # selects corresponding sublcass
    def self.select_from_datasat(inputdata, config)
      data = inputdata.dup
      oldurl = data.delete("url")
      if oldurl =~ /^([AV])---/
        data["url"] = oldurl.split("---").last
      else
        data["url"] = "#{config[:variant] == :audio ? "A" : "V"}---#{oldurl}"
        return select_from_datasat(data, config)
      end
      clz = $1 == "A" ? Audio : Video
      clz.new(data, config)
    end

    def initialize(data, config)
      @config = config
      @data = data
    end

    def data_field(which)
      data[which.to_s]
    end

    def url
      data_field(:url)
    end

    def ytdlp_default_arguments(*args)
      [ '-o %(title).200s.%(ext)s', '--restrict-filenames',
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
    def initialize(wrapperinst)
      @media = wrapperinst
    end

    def command
      [bin, @media.full_arguments].flatten.map { |p| Shellwords.split(p) }.flatten
    end
    
    def bin
      "yt-dlp"
    end

    def download
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
  
  mqtt.subscribe(TOPIC) do |data|
    #     data = {
    #       "senderid" => 345436757865,
    #       "parameters"=>["-P /tmp"],
    #       "url" => "https://www.youtube.com/watch?v=5CLeGECv-1I"
    #     }
    ytdlwr = YTDLWrapper[data]
    Trompie.log "choosing: %s:%s" % [ytdlwr.media.class, ytdlwr.media.url]
    ytdlwr.download
  end
end

#p Trompie::HA.new.make_req(:states, "sensor.temperature")
