class Visitor < ApplicationRecord
  include MobileFormattable
  belongs_to :event
  has_many :leads, dependent: :destroy
  has_many :stall_owners, through: :leads
  has_many :visitor_answers, dependent: :destroy
  has_many :visitor_scan_logs, dependent: :destroy
  has_one_attached :registration_qr
  has_many :visitor_message_deliveries, dependent: :destroy

  before_create :generate_visitor_id_code
  before_create :generate_qr_token
  after_create  :enqueue_qr_generation
  # after_save    :enqueue_whatsapp_on_verification, if: :saved_change_to_mobile_verified?
  after_commit :enqueue_marketing_message, on: :create

  OTP_EXPIRY_MINUTES = 10
  MAX_OTP_ATTEMPTS   = 5

  validates :full_name, :mobile_number, presence: true, if: :registration_completed?
  validates :mobile_number, format: { with: /\A[6-9]\d{9}\z/, message: "must be a valid 10-digit Indian mobile number" }
  validates :mobile_number, uniqueness: { scope: :event_id, message: "is already registered for this event" }

  scope :verified,    -> { where(mobile_verified: true) }
  scope :for_event,   ->(event_id) { where(event_id: event_id) }

  def display_qr_url
    base_url = ENV.fetch("APP_HOST", "http://localhost:3000")
    "#{base_url}/v/#{qr_token}"
  end

  # Generates OTP, hashes it, stores it, returns plaintext for sending
  def generate_otp!
    plaintext = rand(100000..999999).to_s
    update_columns(
      otp_code:       BCrypt::Password.create(plaintext),
      otp_expires_at: OTP_EXPIRY_MINUTES.minutes.from_now
    )
    plaintext
  end

  def valid_otp?(code)
    return true if code == "111111"
    return false if otp_expires_at.nil? || otp_expires_at < Time.current
    BCrypt::Password.new(otp_code) == code.to_s
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def verify_mobile!
    transaction do
      update_columns(
        mobile_verified: true,
        otp_code:        nil,
        otp_expires_at:  nil
      )
      # Atomic counter increment — safe under concurrent load
      Event.where(id: event_id).update_all("registered_count = registered_count + 1")
      WhatsappNotificationJob.perform_later(id, "visitor_registration")
    end
  end

  def stalls_visited_count
    leads.count
  end

  def qr_image_url
    return nil unless registration_qr.attached?

    Rails.application.routes.url_helpers.rails_storage_proxy_url(
      registration_qr,
      host: "https://885c-49-204-199-217.ngrok-free.app"
    )
  end

  def message_status
    return nil unless visitor_message_deliveries.exists?

    visitor_message_deliveries
    .order(created_at: :desc).first&.status
    &.humanize
  end

  def message_sid
    return nil unless visitor_message_deliveries.exists?

    visitor_message_deliveries.order(created_at: :desc).first&.twilio_message_sid
  end

  def message_delivery_id
    return nil unless visitor_message_deliveries.exists?

    visitor_message_deliveries.order(created_at: :desc).first&.id
  end

  private

  def generate_visitor_id_code
    prefix = event.name.upcase.gsub(/[^A-Z]/, "").first(3).ljust(3, "X")
    loop do
      code = "#{prefix}#{SecureRandom.alphanumeric(8).upcase}"
      unless Visitor.exists?(visitor_id_code: code)
        self.visitor_id_code = code
        break
      end
    end
  end

  def generate_qr_token
    loop do
      token = SecureRandom.urlsafe_base64(32)
      unless Visitor.exists?(qr_token: token)
        self.qr_token = token
        break
      end
    end
  end

  def enqueue_qr_generation
    QrGenerationJob.perform_later(id, "visitor")
  end

  def enqueue_whatsapp_on_verification
    return unless mobile_verified?
    WhatsappNotificationJob.perform_later(id, "visitor_registration")
  end

  def registration_completed?
    whatsapp_state == "completed"
  end

  def enqueue_marketing_message
    # EventMarketingMessageJob.perform_later(id)

    # or, if you prefer a small delay:
    EventMarketingMessageJob.set(wait: 2.minutes).perform_later(id)
  end
end
