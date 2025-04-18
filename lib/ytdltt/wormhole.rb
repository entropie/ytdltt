require "pty"

module Wormhole

 
  def self.available?
    system("which wormhole > /dev/null 2>&1")
  end

  def self.ytdltt_block
    -> (file, wrapper, timeout, *args) { 
      Wormhole.send_file(file, timeout: timeout) do |code|
        wrapper.send_reply("#{code}")
      end
    }
  end

  def self.send_file(file_path, timeout: 120, &on_code)
    Thread.new do
      begin
        PTY.spawn("wormhole send #{Shellwords.escape(file_path)}") do |stdout, stdin, pid|
          start_time = Time.now

          stdout.each do |line|
            if line.include?("Wormhole code is:")
              code = line[/Wormhole code is:\s*(\S+)/, 1]
              Trompie.debug{ Trompie.log "Got wormhole code: #{code} for #{file_path} for #{timeout}sec" }
              on_code.call(code) if code && on_code
            end

            break if line.include?("File sent") || line.include?("Goodbye")

            if Time.now - start_time > timeout
              Trompie.debug { Trompie.log "Timeout, killing wormhole #{file_path}" }
              Process.kill("TERM", pid)
              break
            end
          end
        end
      rescue PTY::ChildExited, Errno::EIO => e
        puts "Wormhole process exited: #{e.message}"
      end
    end
  end
end
