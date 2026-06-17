class Event < ApplicationRecord
  belongs_to :event_organizer
  has_many :stall_owners, dependent: :destroy
  has_many :visitors, dependent: :destroy
  has_many :leads, dependent: :destroy
  has_one  :event_analytics, dependent: :destroy

  before_create :generate_slug
  before_create :generate_registration_qr_token
  after_create  :generate_qr_image_async
  after_create  :initialize_analytics

  STATUSES = %w[draft active completed archived].freeze

  validates :name, :venue, :start_date, :end_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :slug, uniqueness: true
  validates :registration_qr_token, uniqueness: true
  validate  :end_date_after_start_date

  scope :active_events, -> { where(status: "active") }
  scope :upcoming,      -> { where("start_date >= ?", Date.today) }
  scope :by_organizer,  ->(organizer_id) { where(event_organizer_id: organizer_id) }

  def registration_url
    base_url = ENV.fetch("APP_HOST", "http://localhost:3000")
    "#{base_url}/register/#{registration_qr_token}"
  end

  def verified_visitor_count
    visitors.where(mobile_verified: true).count
  end

  def active?
    status == "active"
  end

  private

  def generate_slug
    base = name.parameterize
    self.slug = "#{base}-#{SecureRandom.hex(4)}"
    # Ensure uniqueness
    while Event.exists?(slug: self.slug)
      self.slug = "#{base}-#{SecureRandom.hex(4)}"
    end
  end

  def generate_registration_qr_token
    self.registration_qr_token = SecureRandom.urlsafe_base64(32)
  end

  def generate_qr_image_async
    QrGenerationJob.perform_later(id, "event")
  end

  def initialize_analytics
    EventAnalytics.create!(event: self)
  end

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?
    errors.add(:end_date, "must be on or after start date") if end_date < start_date
  end
end
