require "test_helper"

class LogContentTest < ActiveSupport::TestCase
  test "text logs are detected as text" do
    assert LogContent.text?(StringIO.new("hello\nworld\n"))
  end

  test "binary content with null bytes is rejected" do
    assert_not LogContent.text?(StringIO.new("good\x00bad"))
  end

  test "empty content is rejected" do
    assert_not LogContent.text?(StringIO.new(""))
  end

  test "ELF binary is rejected" do
    elf = "\x7fELF\x02\x01\x01\x00" + ("\x00" * 50)
    assert_not LogContent.text?(StringIO.new(elf))
  end

  test "utf-8 with accents is accepted" do
    assert LogContent.text?(StringIO.new("café\nrésumé\n"))
  end

  test "invalid utf-8 is rejected" do
    assert_not LogContent.text?(StringIO.new("\xff\xfe\xfd\xfc"))
  end
end
