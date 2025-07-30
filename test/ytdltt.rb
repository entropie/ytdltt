require "minitest/autorun"
require_relative "../ytdltt"


module Input
  INPUTS = [
    {"url": "https://www.youtube.com/watch?v=I8mS8Pfgros", "senderid": 849936978, "parameters": [], "mid": 2834}
  ]
end


class TestParameters < Minitest::Test
  include Input
  def setup
    @input = Input::INPUTS.first
    @wrapper = YTDLTT::YTDLWrapper[@input]
  end

  def test_target_from_parameter
    newp = ["-P", "/tmp"]
    a = @input.merge(parameters: newp)
    @wrapper = YTDLTT::YTDLWrapper[a]
    
    assert_equal ["-P", "temp:/tmp/.tmp", "-P", "home:/tmp"], @wrapper.media.path_arguments
    assert_equal "/tmp", @wrapper.media.target_directory
  end

  def test_target_from_no_parameter
    @wrapper = YTDLTT::YTDLWrapper[@input]
    assert_equal @wrapper.media.user_arguments, []
    assert_equal @wrapper.media.target_directory, "/home/media/youtube"
  end

  def test_other_user_parameter
    newp = ["--foo", "bar", "-P", "/tmp", "keke", "lala"]

    a = @input.merge(parameters: newp)
    @wrapper = YTDLTT::YTDLWrapper[a]
    assert_equal "/tmp", @wrapper.media.target_directory
    assert_equal ["--foo", "bar", "keke", "lala"], @wrapper.media.user_arguments
  end

end


class TestDataset < Minitest::Test
  include Input
  def setup
    @input = Input::INPUTS.first.dup
    @wrapper = YTDLTT::YTDLWrapper[@input]
  end

  def test_if_class_is_video
    assert_instance_of YTDLTT::Video, YTDLTT::YTDLWrapper.select_from_dataset(@input, {  })
  end

  def test_if_class_is_audio
    @input[:url] = "A---%s" % @input[:url]
    assert_instance_of YTDLTT::Audio, YTDLTT::YTDLWrapper.select_from_dataset(@input, {  })
  end

end
