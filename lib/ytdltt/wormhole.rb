require "open3"

module Wormhole

  def self.send_file(file_path, timeout: 120, &on_code)
    Thread.new do
      code = nil
      Open3.popen3("wormhole", "send", file_path.to_s) do |stdin, stdout, stderr, wait_thr|
        start_time = Time.now

        stdout.each_line do |line|
          Trompie.log line
          if line =~ /Wormhole code is: (\S+)/
            code = $1
            on_code.call(code) if code && on_code
          end

          break if line.include?("File sent") || line.include?("Goodbye")

          # Timeout-Check (no client connected)
          if Time.now - start_time > timeout
            Trompie.warn "Wormhole timeout – killing sender after #{timeout} seconds"
            Process.kill("TERM", wait_thr.pid)
            break
          end
        end
      end
    end
  end

end
