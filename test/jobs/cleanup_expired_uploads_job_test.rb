require "test_helper"

class CleanupExpiredUploadsJobTest < ActiveJob::TestCase
  test "soft-deletes uploads expired beyond grace period" do
    long_expired = create_upload(expires_at: 2.hours.ago)
    just_expired = create_upload(expires_at: 1.minute.ago)
    fresh        = create_upload(expires_at: 1.hour.from_now)

    CleanupExpiredUploadsJob.perform_now

    assert long_expired.reload.deleted_at.present?
    assert_nil just_expired.reload.deleted_at
    assert_nil fresh.reload.deleted_at
  end

  test "skips already-deleted uploads" do
    upload = create_upload(expires_at: 2.hours.ago, deleted_at: 1.hour.ago)
    original = upload.deleted_at

    CleanupExpiredUploadsJob.perform_now

    assert_in_delta original, upload.reload.deleted_at, 1.second
  end

  private

  def create_upload(**overrides)
    Upload.create!({ byte_size: 10, sha256: "a" * 64, expires_at: 1.hour.from_now }.merge(overrides))
  end
end
