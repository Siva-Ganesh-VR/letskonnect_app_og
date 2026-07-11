class Lead < ApplicationRecord
  include MobileFormattable
  belongs_to :visitor
  belongs_to :stall_owner
  belongs_to :event

  after_create :broadcast_new_lead
  after_create :enqueue_analytics_update
  after_create :enqueue_visitor_notification

  TEMPERATURES = %w[hot warm cold].freeze
  STATUSES     = %w[new contacted interested follow_up converted lost].freeze

  validates :visitor_id,     uniqueness: { scope: :stall_owner_id, message: "already captured at this stall" }
  validates :interest_rating, inclusion: { in: 1..5 }
  validates :temperature,     inclusion: { in: TEMPERATURES }
  validates :status,          inclusion: { in: STATUSES }
  validates :scanned_at,      presence: true

  scope :for_stall,     ->(stall_id)  { where(stall_owner_id: stall_id) }
  scope :today,         ->            { where("scanned_at >= ?", Time.zone.today.beginning_of_day) }
  scope :hot,           ->            { where(temperature: "hot") }
  scope :warm,          ->            { where(temperature: "warm") }
  scope :cold,          ->            { where(temperature: "cold") }
  scope :follow_up_due, ->            { where(follow_up_date: Date.today) }
  scope :converted,     ->            { where(status: "converted") }

  def self.summary_for_stall(stall_owner_id)
    base = where(stall_owner_id: stall_owner_id)
    {
      total:           base.count,
      today:           base.today.count,
      hot:             base.hot.count,
      warm:            base.warm.count,
      cold:            base.cold.count,
      new_leads:       base.where(status: "new").count,
      interested:      base.where(status: "interested").count,
      follow_up:       base.where(status: "follow_up").count,
      converted:       base.converted.count,
      follow_up_today: base.follow_up_due.count
    }
  end

  private

  def broadcast_new_lead
    ActionCable.server.broadcast(
      "leads_#{stall_owner_id}",
      {
        type:          "new_lead",
        lead_id:       id,
        visitor_name:  visitor.full_name,
        business_name: visitor.business_name,
        category:      visitor.business_category,
        scanned_at:    scanned_at.iso8601
      }
    )
  end

  def enqueue_analytics_update
    UpdateLeadAnalyticsJob.perform_later(stall_owner_id, event_id)
    # Atomic counter on stall_owner
    StallOwner.where(id: stall_owner_id).update_all("total_leads_count = total_leads_count + 1")
  end

  def enqueue_visitor_notification
    WhatsappNotificationJob.perform_later(visitor_id, "stall_visit", stall_owner_id)
  end
end
