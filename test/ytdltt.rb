require "minitest/autorun"
require_relative "../ytdltt"

# class TestYTDLWrapperBase < Minitest::Test
#   def setup
#     @config = {
#       audioIncoming: "/tmp/audio",
#       videoIncoming: "/tmp/video",
#       variant: :audio
#     }
#   end

# end

class TestReply < Minitest::Test

  def setup
    @input = {"url": "https://www.youtube.com/watch?v=I8mS8Pfgros", "senderid": 849936978, "parameters": [], "mid": 2834}
    @input1 = {"url": "V---https://www.youtube.com/watch?v=I8mS8Pfgros", "senderid": 849936978, "parameters": [], "mid": 2834}
    @wrapper = YTDLTT::YTDLWrapper[@input]
    @wrapper1 = YTDLTT::YTDLWrapper[@input1]
  end

  def test_t1
    # puts
    # pp @wrapper.media
  end
  def test_t2
    @wrapper1.download do |dwnld|
      dwnld.send_reply

    end
  end
end
