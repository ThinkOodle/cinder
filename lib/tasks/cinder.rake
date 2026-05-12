namespace :cinder do
  desc "Soft-delete an upload by slug. Usage: bin/rails 'cinder:delete[slug]'"
  task :delete, [ :slug ] => :environment do |_, args|
    upload = Upload.find_by!(slug: args.fetch(:slug))
    upload.soft_delete!
    puts "deleted #{upload.slug}"
  end

  desc "Block an upload by slug (returns 404 publicly). Usage: bin/rails 'cinder:block[slug]'"
  task :block, [ :slug ] => :environment do |_, args|
    upload = Upload.find_by!(slug: args.fetch(:slug))
    upload.update!(moderation_status: :blocked)
    upload.file.purge_later if upload.file.attached?
    puts "blocked #{upload.slug}"
  end

  desc "Run cleanup now (used by recurring schedule in production)"
  task cleanup: :environment do
    CleanupExpiredUploadsJob.perform_now
    puts "cleanup complete"
  end

  desc "Show stats"
  task stats: :environment do
    puts "live:    #{Upload.live.count}"
    puts "expired: #{Upload.expired.count}"
    puts "blocked: #{Upload.blocked.count}"
    puts "deleted: #{Upload.where.not(deleted_at: nil).count}"
  end
end
