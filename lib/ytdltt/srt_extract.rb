require "set"

module SRTExtract

  # chatgpts way to extract youtubes auto generated srt (test/subtitles/a1rIo4a6sOU.de.srt)
  # which had weird (?) line repeatings
  def self.extract_subtitles(srt_content, all_in_one_line: false, interval_in_one_line: false, preserve_lines: true)
    seen = Set.new
    just_read_num = false
    just_read_interval = false
    output = ''

    srt_content.each_line do |raw_line|
      line = raw_line.chomp

      if line =~ /^\d+$/
        just_read_num = true
        just_read_interval = false

      elsif just_read_num
        if m = line.match(/^(?<time>\d{2,}:[0-5]\d:[0-5]\d,\d{3}\s*-->\s*\d{2,}:[0-5]\d:[0-5]\d,\d{3})(?<text>.*)$/)
          just_read_num = false
          just_read_interval = true
          text_inline = m[:text].strip
          if !text_inline.empty? && !seen.include?(text_inline)

            if all_in_one_line
              output << (output.empty? ? text_inline : " #{text_inline}")
            elsif interval_in_one_line
              output << "#{text_inline}\n"
            elsif preserve_lines
              output << "#{text_inline}\n"
            else
              output << "#{text_inline} "
            end
            seen.add(text_inline)
          end
        end

      elsif just_read_interval
        content = line.strip
        next if content.empty? || seen.include?(content)
        if all_in_one_line
          output << (output.empty? ? content : " #{content}")
        elsif interval_in_one_line
          output << "#{content}\n"
        elsif preserve_lines
          output << "#{content}\n"
        else
          output << "#{content} "
        end
        seen.add(content)
      end
    end

    output.strip
  end
end
