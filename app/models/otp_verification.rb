class OtpVerification < ApplicationRecord
  MAX_ATTEMPTS = 5

  validates :mobile_number, :otp_code, :purpose, presence: true

  PURPOSES = %w[stall_login organizer_login].freeze

  scope :active,      -> { where(used: false).where("expires_at > ?", Time.current) }
  scope :for_mobile,  ->(mobile) { where(mobile_number: mobile) }

  def self.generate_for(mobile_number, purpose:, ip: nil)
    # Clean up old ones for this mobile+purpose
    where(mobile_number: mobile_number, purpose: purpose).delete_all

    plaintext = rand(100000..999999).to_s
    record = create!(
      mobile_number: mobile_number,
      otp_code:      BCrypt::Password.create(plaintext),
      purpose:       purpose,
      expires_at:    10.minutes.from_now,
      ip_address:    ip
    )
    [plaintext, record]
  end

  def self.verify!(mobile_number, code, purpose:)
    record = active.for_mobile(mobile_number).find_by(purpose: purpose)
    return :not_found unless record
    return :expired  if record.expires_at < Time.current

    record.increment!(:attempts)
    return :max_attempts if record.attempts > MAX_ATTEMPTS
    return :invalid      unless BCrypt::Password.new(record.otp_code) == code.to_s

    record.update!(used: true)
    :valid
  rescue BCrypt::Errors::InvalidHash
    :invalid
  end
end
