class Upload < ApplicationRecord
  SLUG_LENGTH = 6
  MAX_SLUG_RETRIES = 5

  has_one_attached :file

  enum :moderation_status, { active: "active", blocked: "blocked" }, default: :active, validate: true

  scope :live,    -> { active.where(deleted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  before_validation :assign_slug, on: :create

  validates :slug,       presence: true, uniqueness: true
  validates :byte_size,  presence: true, numericality: { greater_than: 0 }
  validates :sha256,     presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :expires_at, presence: true

  def self.find_live(slug)
    live.find_by(slug: slug)
  end

  def to_param
    slug
  end

  def expired?
    expires_at <= Time.current
  end

  def gone?
    deleted_at.present? || blocked? || expired?
  end

  def soft_delete!
    return if deleted_at?

    transaction do
      update!(deleted_at: Time.current)
      file.purge_later if file.attached?
    end
  end

  private

  def assign_slug
    return if slug.present?

    MAX_SLUG_RETRIES.times do
      candidate = SecureRandom.alphanumeric(SLUG_LENGTH)
      unless self.class.exists?(slug: candidate)
        self.slug = candidate
        return
      end
    end

    raise "Unable to generate unique slug after #{MAX_SLUG_RETRIES} attempts"
  end
end
