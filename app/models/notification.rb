class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true
  belongs_to :event, optional: true

  TYPES    = %w[visitor_registration stall_visit daily_summary export_ready follow_up_reminder event_reminder].freeze
  CHANNELS = %w[whatsapp sms push].freeze
  STATUSES = %w[pending sent failed delivered].freeze

  validates :notification_type, inclusion: { in: TYPES }
  validates :channel,           inclusion: { in: CHANNELS }
  validates :status,            inclusion: { in: STATUSES }

  scope :pending_retry, -> {
    where(status: "failed")
      .where("retry_count < 3")
      .where("updated_at < ?", 5.minutes.ago)
  }
end
