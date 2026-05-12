class CleanupExpiredUploadsJob < ApplicationJob
  queue_as :default

  def perform
    cutoff = Time.current - Cinder.cleanup_grace_minutes.minutes
    Upload.where("expires_at <= ?", cutoff).where(deleted_at: nil).find_each(&:soft_delete!)
  end
end
