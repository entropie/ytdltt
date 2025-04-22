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

#selected_path = "/etc/nixos/res/gems/trompie/lib"

$LOAD_PATH.unshift(selected_path)

require "trompie"
Trompie.log_basedir

$stdout.sync = true

module YTDLTT

  include Trompie

  TOPIC = "yt/dl"

  class YTDLWrapper
    attr_reader :data

    DEFAULTS ={
      variant: :audio,
      videoIncoming: "/home/media/youtube",
      audioIncoming: "/home/media/youtube"
    }

    attr_accessor *DEFAULTS.keys
    attr_accessor :config
    attr_accessor :filename

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
      ret = Downloader.new(select_from_datasat(inputdata.extend(Dataset).nrmlz, config))
      ret
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
      normalize_paths!
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
      [ '-o', title_template, '--restrict-filenames', '--print', 'after_move:filepath',
        '--no-playlist', '--no-post-overwrites', '--no-mtime', '--no-write-comments' ] + args
    end

    def full_arguments
      [ytdlp_default_arguments,
       path_arguments,
       user_arguments,
       url].flatten
    end

    def path_arguments
      ret = []
      ret.push("-P", "temp:%s/.tmp" % [target_directory])
      ret.push("-P", "home:%s" % [target_directory])
      #p directories = [ret[1], ret[3]].map{ |d| d.split(":").last }
      ret
    end

    def user_or_default_target_directory(kind)
      unless @target_directory
        uparams = Array(@data[:parameters])
        user_pathind = uparams.index("-P")
        if user_pathind && uparams[user_pathind + 1]
          @target_directory = uparams[user_pathind + 1]
        else
          @target_directory = config[kind.to_sym]
        end
      end
      @target_directory  
    end

    def normalize_paths!
      target_directory
      user_arguments
    end

    def user_arguments
      unless @user_arguments
        params = Array(@data[:parameters])
        Trompie.debug { Trompie.log "YTDLTT::Params: #{data.inspect}" }
        if (i = params.index("-P"))
          params.slice!(i, 2)
        end
        @user_arguments = params
      end
      @user_arguments
    end
  end

  class Audio < YTDLWrapper
    def ytdlp_default_arguments
      super '-f bestaudio', '--extract-audio', '--audio-format mp3', '--audio-quality 0'
    end

    def target_directory
      user_or_default_target_directory(:audioIncoming)
    end
  end

  class Video < YTDLWrapper
    def ytdlp_default_arguments
      super '-f bestvideo+bestaudio/best', '--merge-output-format mp4'
    end
    
    def target_directory
      user_or_default_target_directory(:videoIncoming)
    end
  end

  class Downloader

    include Trompie

    attr_reader :media
    attr_accessor :mqtt, :bin
    attr_reader :filename

    WORMHOLE_TIMEOUT = 2*60

    def initialize(wrapperinst)
      @media = wrapperinst
    end

    def self.download_syncron(url, target_dir, &blk)
      optionhash = { url: url, parameters: ["-P", target_dir] }
      wrapper = YTDLWrapper[optionhash]
      wrapper.download(&blk)
    end

    def self.queue
      @queue ||= Queue.new
    end

    def self.mqtt
      @mqtt ||= MMQTT.new
    end

    def self.loop!
      thread!
      Trompie.debug { Trompie.log "YTDLTT: subscribing #{TOPIC}" }
      mqtt.subscribe(TOPIC) do |data|
        next if data.respond_to?(:empty?) and data.empty?
        Trompie.debug { Trompie.log "YTDLTT::MQTT queueing incoming message: #{data.inspect}" }
        Downloader.queue << data
      end
    end

    def self.thread!
      Trompie.debug { Trompie.log "YTDLTT: looping the queue" }
      Thread.new do
        loop do
          data = Downloader.queue.pop
          begin
            ytdlwr = YTDLTT::YTDLWrapper[data]
            Trompie.debug { Trompie.log "YTDLTT: %s: %s" % [ytdlwr.media.class, ytdlwr.media.url] }

            ret, filename = ytdlwr.download
            if Wormhole.available?
              Wormhole.ytdltt_block.call(filename, ytdlwr, WORMHOLE_TIMEOUT)
            end

          rescue => e
            Trompie.debug{ Trompie.log "YTDLTT: Download failed: #{e.class} - #{e.message}" } 
          end
        end
      end
    end

    def command
      [bin, @media.full_arguments].flatten.map { |p| Shellwords.split(p) }.flatten
    end
    
    def bin
      @bin || "yt-dlp"
    end

    def download(&blk)
      retval, filename = run_download_command!
      media.filename = filename

      yield self if block_given?

      [retval, filename]
    end

    def run_download_command!
      filename = nil

      Trompie.debug { log "YTDLTT::Command: '%s'" %  command.join(" ")}

      Open3.popen2e(*command) do |stdin, stdout_and_err, wait_thr|
        stdout_and_err.each_line do |line|
          filename = line.strip
        end
        Trompie.debug { log "YTDLTT::Download finished #{filename}" }

        exit_status = wait_thr.value
        unless exit_status.success?
          return [false, filename]
        end
      end
      [true, filename]
    end

    def send_reply(content)
      topic = "telegram/message"
      chatid, message_id = media.data[:senderid], media.data[:mid]
      rep = { type: :message, 
              chatId: chatid,
              content: content,
              options: { reply_to_message_id: message_id}, "parse_mode": "Markdown" }
      Trompie.debug { Trompie.log "YTDLTT::MQTT(#{topic}) submitting #{rep.inspect}" }
      Downloader.mqtt.
        submit(topic, JSON.generate(rep), retain: false)
    end

  end

end

