module Cinder
  MAX_UPLOAD_BYTES_RANGE = (5 * 1024 * 1024)..(20 * 1024 * 1024)
  TTL_HOURS_RANGE        = 1..24

  module_function

  def max_upload_bytes
    clamp ENV.fetch("CINDER_MAX_UPLOAD_BYTES", 10 * 1024 * 1024).to_i, MAX_UPLOAD_BYTES_RANGE, "CINDER_MAX_UPLOAD_BYTES"
  end

  def default_ttl_hours
    clamp ENV.fetch("CINDER_DEFAULT_TTL_HOURS", 24).to_i, TTL_HOURS_RANGE, "CINDER_DEFAULT_TTL_HOURS"
  end

  def min_ttl_hours
    clamp ENV.fetch("CINDER_MIN_TTL_HOURS", 1).to_i, TTL_HOURS_RANGE, "CINDER_MIN_TTL_HOURS"
  end

  def max_ttl_hours
    clamp ENV.fetch("CINDER_MAX_TTL_HOURS", 24).to_i, TTL_HOURS_RANGE, "CINDER_MAX_TTL_HOURS"
  end

  def cleanup_grace_minutes = ENV.fetch("CINDER_CLEANUP_GRACE_MINUTES", 60).to_i

  def clamp(value, range, name)
    return value if range.cover?(value)
    Rails.logger.warn("[cinder] #{name}=#{value} out of range #{range}; clamping")
    value.clamp(range.min, range.max)
  end
end
