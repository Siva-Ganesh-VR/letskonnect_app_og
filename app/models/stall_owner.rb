class StallOwner < ApplicationRecord
  has_secure_password

  belongs_to :event
  belongs_to :event_organizer, optional: true
  has_many :leads, dependent: :destroy
  has_many :visitors, through: :leads
  has_one  :stall_analytics, dependent: :destroy

  before_create :set_jti
  after_create  :initialize_analytics

  validates :name, :mobile_number, :company_name, presence: true
  validates :mobile_number, format: { with: /\A[6-9]\d{9}\z/, message: "must be valid 10-digit Indian mobile" }
  validates :stall_number, uniqueness: { scope: :event_id }, allow_blank: true

  scope :active,    -> { where(active: true) }
  scope :for_event, ->(event_id) { where(event_id: event_id) }

  def issue_token
    ApplicationController.issue_token(sub: id, role: "stall_owner", jti: jti)
  end

  def invalidate_token!
    update_column(:jti, SecureRandom.uuid)
  end

  def dashboard_summary
    {
      total:           leads.count,
      today:           leads.where("scanned_at >= ?", Time.zone.today.beginning_of_day).count,
      hot:             leads.where(temperature: "hot").count,
      warm:            leads.where(temperature: "warm").count,
      cold:            leads.where(temperature: "cold").count,
      new_leads:       leads.where(status: "new").count,
      interested:      leads.where(status: "interested").count,
      follow_up:       leads.where(status: "follow_up").count,
      converted:       leads.where(status: "converted").count,
      follow_up_today: leads.where(follow_up_date: Date.today).count
    }
  end

  private
  def set_jti; self.jti ||= SecureRandom.uuid; end
  def initialize_analytics
    StallAnalytics.create!(stall_owner: self, event: event)
  end
end
