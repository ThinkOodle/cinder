require "test_helper"

class UploadTest < ActiveSupport::TestCase
  test "assigns a slug on create" do
    upload = build_upload
    upload.save!
    assert_match(/\A[A-Za-z0-9]+\z/, upload.slug)
    assert_equal Upload::SLUG_LENGTH, upload.slug.length
  end

  test "to_param returns the slug" do
    upload = build_upload(slug: "abc123")
    assert_equal "abc123", upload.to_param
  end

  test "live scope excludes expired, deleted, and blocked" do
    fresh   = create_upload
    expired = create_upload(expires_at: 1.minute.ago)
    deleted = create_upload(deleted_at: Time.current)
    blocked = create_upload(moderation_status: :blocked)

    slugs = Upload.live.pluck(:slug)
    assert_includes slugs, fresh.slug
    assert_not_includes slugs, expired.slug
    assert_not_includes slugs, deleted.slug
    assert_not_includes slugs, blocked.slug
  end

  test "soft_delete sets deleted_at and purges file" do
    upload = create_upload
    upload.file.attach(io: StringIO.new("log"), filename: "log.txt", content_type: "text/plain")
    upload.soft_delete!
    assert upload.deleted_at.present?
  end

  test "find_live returns nil for gone uploads" do
    upload = create_upload(deleted_at: Time.current)
    assert_nil Upload.find_live(upload.slug)
  end

  private

  def build_upload(**overrides)
    Upload.new({
      byte_size:  10,
      sha256:     "a" * 64,
      expires_at: 1.hour.from_now
    }.merge(overrides))
  end

  def create_upload(**overrides)
    build_upload(**overrides).tap(&:save!)
  end
end
