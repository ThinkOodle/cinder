class UploadsController < ApplicationController
  skip_forgery_protection

  rate_limit to: 5,  within: 1.minute, name: "upload_minute", by: -> { client_ip }, with: -> { rate_limited("minute") }, only: :create
  rate_limit to: 25, within: 1.hour,   name: "upload_hour",   by: -> { client_ip }, with: -> { rate_limited("hour") },   only: :create

  def create
    file = params[:file]
    return reject(:bad_request,           "missing_file",  "missing file")   unless file.respond_to?(:read) && file.respond_to?(:size)
    return reject(:content_too_large,     "too_large",     "file too large") if file.size > Cinder.max_upload_bytes
    return reject(:bad_request,           "empty_file",    "empty file")     if file.size.zero?
    return reject(:unsupported_media_type, "not_text",     "logs only")      unless LogContent.text?(file.tempfile || file)

    upload = Upload.create!(
      byte_size:   file.size,
      sha256:      sha256_of(file),
      expires_at:  Time.current + ttl_from(params[:expires]),
      uploader_ip: client_ip,
      user_agent:  request.user_agent.to_s.first(255)
    )

    begin
      upload.file.attach(io: file.tempfile || file, filename: "log.txt", content_type: "text/plain")
    rescue => e
      upload.update_columns(deleted_at: Time.current)
      Rails.logger.error(event: "cinder.attach_failed", slug: upload.slug, error: e.class.name)
      return text_error(:service_unavailable, "upload failed")
    end

    render plain: "#{upload_url(upload)}\n", status: :created
  end

  def show
    upload = Upload.find_live(params[:slug])
    return not_found unless upload && upload.file.attached?

    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Robots-Tag"]           = "noindex, nofollow"
    response.headers["Cache-Control"]          = "private, no-store"
    send_data upload.file.download,
      type: "text/plain; charset=utf-8",
      disposition: "inline",
      filename: "#{upload.slug}.log"
  end

  private

  def sha256_of(file)
    digest = Digest::SHA256.new
    io = file.tempfile || file
    io.rewind
    while (chunk = io.read(64.kilobytes))
      digest.update(chunk)
    end
    io.rewind
    digest.hexdigest
  end

  def ttl_from(expires)
    hours = Integer(expires, 10) rescue nil
    capped = [ [ hours || Cinder.default_ttl_hours, Cinder.min_ttl_hours ].max, Cinder.max_ttl_hours ].min
    capped.hours
  end

  def reject(status, reason, message)
    Rails.logger.info(event: "cinder.reject", reason: reason, ip: client_ip, ua: request.user_agent)
    text_error(status, message)
  end

  def text_error(status, message)
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    render plain: "#{message}\n", status: status
  end

  def rate_limited(bucket)
    Rails.logger.info(event: "cinder.rate_limited", bucket: bucket, ip: client_ip)
    text_error(:too_many_requests, "rate limited")
  end

  def not_found
    text_error(:not_found, "not found")
  end
end
