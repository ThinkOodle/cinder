Rails.application.config.exceptions_app = ->(env) {
  status = env["PATH_INFO"].to_s.delete_prefix("/").to_i
  status = 500 unless (400..599).cover?(status)
  message = Rack::Utils::HTTP_STATUS_CODES[status] || "error"

  [
    status,
    { "content-type" => "text/plain; charset=utf-8", "x-content-type-options" => "nosniff" },
    [ "#{message.downcase}\n" ]
  ]
}
