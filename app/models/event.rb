
class Event < ApplicationRecord
  belongs_to :event_organizer
  has_many :stall_owners, dependent: :destroy
  has_many :visitors,     dependent: :destroy
  has_many :leads,        dependent: :destroy
  has_one  :event_analytics, dependent: :destroy
  has_many :visitor_scan_logs, dependent: :destroy

  before_create :generate_slug
  before_create :generate_registration_qr_token
  before_create :generate_event_code          # ← NEW
  after_create  :generate_qr_image_async
  after_create  :initialize_analytics

  STATUSES = %w[pending draft active completed archived].freeze

  validates :name,    :venue, :start_date, :end_date, presence: true
  validates :status,  inclusion: { in: STATUSES }
  validates :slug,    uniqueness: true
  validates :registration_qr_token, uniqueness: true
  validates :event_code, uniqueness: true, allow_nil: true  # nil only during migration backfill
  validate  :end_date_after_start_date
  before_validation :format_name
  
  scope :active_events, -> { where(status: "active") }
  scope :upcoming,      -> { where("start_date >= ?", Date.today) }
  scope :by_organizer,  ->(organizer_id) { where(event_organizer_id: organizer_id) }

  def name
    self[:name]&.titleize
  end

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

  def format_name
    self.name = name.to_s.titleize if name.present?
  end

  # ── Generates EXP-YYYY-XXXX ──────────────────────────────────────────────
  def generate_event_code
    year = Time.current.year

    # SELECT ... FOR UPDATE prevents two simultaneous creates getting the same number
    last = Event
             .where("event_code LIKE ?", "EXP-#{year}-%")
             .order(:event_code)
             .lock
             .last

    next_seq = last ? last.event_code.split("-").last.to_i + 1 : 1

    self.event_code = format("EXP-%d-%04d", year, next_seq)
  end

  def generate_slug
    base = name.parameterize
    self.slug = "#{base}-#{SecureRandom.hex(4)}"
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
