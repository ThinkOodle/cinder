require "test_helper"

class UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @log = fixture_file_upload("sample.log", "text/plain")
    @binary = fixture_file_upload("binary.bin", "application/octet-stream")
    Rails.cache.clear
  end

  test "POST / returns 201 and a plain-text URL" do
    post "/", params: { file: @log }
    assert_response :created
    assert_equal "text/plain", @response.media_type
    body = @response.body.strip
    assert_match %r{\Ahttp://www\.example\.com/[A-Za-z0-9]+\.log\z}, body
    upload = Upload.sole
    assert_equal "log.txt", upload.file.filename.to_s
    assert upload.expires_at.between?(23.hours.from_now, 25.hours.from_now)
  end

  test "POST / without file returns 400" do
    post "/", params: {}
    assert_response :bad_request
    assert_equal "missing file\n", @response.body
  end

  test "POST / with binary returns 415" do
    post "/", params: { file: @binary }
    assert_response :unsupported_media_type
    assert_equal 0, Upload.count
  end

  test "POST / oversized returns 413" do
    big = Tempfile.new([ "big", ".log" ]).tap { |f| f.write("x" * (Cinder.max_upload_bytes + 1)); f.rewind }
    post "/", params: { file: Rack::Test::UploadedFile.new(big.path, "text/plain") }
    assert_response :content_too_large
    assert_equal 0, Upload.count
  end

  test "POST / rate limits after 5 in a minute" do
    6.times { post "/", params: { file: fixture_file_upload("sample.log", "text/plain") } }
    assert_response :too_many_requests
  end

  test "trusts CF-Connecting-IP for rate-limit key and uploader_ip" do
    post "/", params: { file: @log }, headers: { "CF-Connecting-IP" => "203.0.113.42" }
    assert_response :created
    assert_equal "203.0.113.42", Upload.sole.uploader_ip
  end

  test "POST / caps expires above 24h" do
    post "/", params: { file: @log, expires: "999" }
    assert_response :created
    assert Upload.sole.expires_at <= 24.hours.from_now + 1.minute
  end

  test "POST / honors expires within range" do
    post "/", params: { file: @log, expires: "2" }
    assert_response :created
    assert Upload.sole.expires_at.between?(1.hour.from_now + 30.minutes, 2.hours.from_now + 1.minute)
  end

  test "POST / falls back to default ttl on bogus expires" do
    post "/", params: { file: @log, expires: "garbage" }
    assert_response :created
    assert Upload.sole.expires_at.between?(23.hours.from_now, 25.hours.from_now)
  end

  test "GET /:slug.log returns content with safe headers" do
    post "/", params: { file: @log }
    upload = Upload.sole

    get "/#{upload.slug}.log"
    assert_response :ok
    assert_equal "text/plain", @response.media_type
    assert_equal "utf-8", @response.charset
    assert_equal "nosniff", @response.headers["X-Content-Type-Options"]
    assert_equal "noindex, nofollow", @response.headers["X-Robots-Tag"]
    assert_includes @response.body, "omarchy boot start"
  end

  test "GET returns 404 if attachment is missing" do
    upload = Upload.create!(byte_size: 10, sha256: "a" * 64, expires_at: 1.hour.from_now)
    get "/#{upload.slug}.log"
    assert_response :not_found
  end

  test "GET unknown slug returns 404" do
    get "/notreal00.log"
    assert_response :not_found
  end

  test "GET expired returns 404" do
    upload = build_persisted(expires_at: 1.minute.ago)
    get "/#{upload.slug}.log"
    assert_response :not_found
  end

  test "GET deleted returns 404" do
    upload = build_persisted(deleted_at: Time.current)
    get "/#{upload.slug}.log"
    assert_response :not_found
  end

  test "GET blocked returns 404" do
    upload = build_persisted(moderation_status: :blocked)
    get "/#{upload.slug}.log"
    assert_response :not_found
  end

  private

  def build_persisted(**overrides)
    upload = Upload.new({ byte_size: 10, sha256: "a" * 64, expires_at: 1.hour.from_now }.merge(overrides))
    upload.file.attach(io: StringIO.new("log content"), filename: "log.txt", content_type: "text/plain")
    upload.save!
    upload
  end
end
