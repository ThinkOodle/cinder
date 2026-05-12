class LogContent
  SAMPLE_BYTES = 32.kilobytes
  PRINTABLE_RATIO_THRESHOLD = 0.9

  def self.text?(io)
    io.rewind
    sample = io.read(SAMPLE_BYTES) || ""
    io.rewind
    return false if sample.empty?
    return false if sample.include?("\x00")

    sample.force_encoding(Encoding::UTF_8)
    return false unless sample.valid_encoding?

    printable = sample.each_codepoint.count { |c| c == 9 || c == 10 || c == 13 || (c >= 32 && c != 127) }
    printable.to_f / sample.length >= PRINTABLE_RATIO_THRESHOLD
  end
end
