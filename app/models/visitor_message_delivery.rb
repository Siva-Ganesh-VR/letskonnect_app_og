class VisitorMessageDelivery < ApplicationRecord
  STATUSES = %w[pending queued sent delivered read failed].freeze

  belongs_to :event
  belongs_to :visitor
  belongs_to :template, optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }

  validates :visitor_id, uniqueness: { scope: :event_id }

  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }
  scope :sent, -> { where(status: "sent") }
  scope :delivered, -> { where(status: "delivered") }
  scope :read, -> { where(status: "read") }
end