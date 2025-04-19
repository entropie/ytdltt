require "pty"
require "pty"

$stdout.sync = true

module Wormhole
 
  def self.available?
    system("which wormhole > /dev/null 2>&1")
  end

  def self.ytdltt_block
    -> (file, wrapper, timeout, *args) { 

      Trompie.do_with_synced_stdout do
        Wormhole.send_file(file, timeout: timeout) do |code|
          wrapper.send_reply("#{code}")
        end
      end

    }
  end

  def self.send_file(file_path, timeout: 120, &on_code)
    Thread.new do
      begin
        PTY.spawn("wormhole send #{Shellwords.escape(file_path)}") do |stdout, _stdin, pid|
          start_time = Time.now
          buffer = ""

          loop do
            if stdout.ready?
              char = stdout.read_nonblock(1) rescue nil
              break unless char
              buffer << char

              if buffer.include?("\n")
                buffer.lines.each do |line|
                  if line.include?("Wormhole code is:")
                    code = line[/Wormhole code is:\s*(\S+)/, 1]
                    Trompie.debug { Trompie.log "Got wormhole code: #{code} for #{file_path} (#{timeout}s)" }
                    on_code.call(code) if code && on_code
                  end

                  if line.include?("File sent") || line.include?("Goodbye")
                    Trompie.debug { Trompie.log "Wormhole complete for #{file_path}" }
                    raise
                  end
                end
                buffer.clear
              end
            else
              sleep 0.1
            end

            if Time.now - start_time > timeout
              Trompie.debug { Trompie.log "Wormhole timeout for #{file_path} – killing" }
              Process.kill("TERM", pid) rescue nil
              break
            end
          end

          # zombie prevention
          begin
            Process.wait(pid)
          rescue Errno::ECHILD
            Trompie.debug { Trompie.log "Wormhole child already reaped" }
          end
        end
      rescue
        Trompie.debug { Trompie.log "Wormhole finished cleanly for #{file_path}" }
      rescue PTY::ChildExited, Errno::EIO => e
        Trompie.debug { Trompie.log "Wormhole process exited: #{e.message}" }
      rescue => e
        Trompie.debug { Trompie.log "Wormhole failed: #{e.class} - #{e.message}" }
      end
    end
  end

end
