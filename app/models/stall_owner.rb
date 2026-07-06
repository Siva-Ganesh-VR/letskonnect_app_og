class StallOwner < ApplicationRecord
  has_secure_password

  belongs_to :event
  belongs_to :event_organizer, optional: true

  has_many :leads, dependent: :destroy
  has_many :visitors, through: :leads
  has_one :stall_analytics, dependent: :destroy

  before_create :set_jti
  before_create :generate_stall_code
  after_create :initialize_analytics

  validates :name, :mobile_number, :company_name, presence: true

  validates :mobile_number,
            format: {
              with: /\A[6-9]\d{9}\z/,
              message: "must be valid 10-digit Indian mobile"
            }

  validates :stall_number,
            uniqueness: { scope: :event_id },
            allow_blank: true

  validates :stall_code,
            uniqueness: true,
            allow_nil: true

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event_id) { where(event_id: event_id) }

  def issue_token
    ApplicationController.issue_token(
      sub: id,
      role: "stall_owner",
      jti: jti
    )
  end

  def invalidate_token!
    update_column(:jti, SecureRandom.uuid)
  end

  def dashboard_summary
    {
      total: leads.count,
      today: leads.where(
        "scanned_at >= ?",
        Time.zone.today.beginning_of_day
      ).count,
      hot: leads.where(temperature: "hot").count,
      warm: leads.where(temperature: "warm").count,
      cold: leads.where(temperature: "cold").count,
      new_leads: leads.where(status: "new").count,
      interested: leads.where(status: "interested").count,
      follow_up: leads.where(status: "follow_up").count,
      converted: leads.where(status: "converted").count,
      follow_up_today: leads.where(
        follow_up_date: Date.current
      ).count
    }
  end

  # def dashboard_summary
  #   all_leads = Lead.where(
  #     stall_owner_id: StallOwner.where(mobile_number: mobile_number).select(:id)
  #   )

  #   {
  #     total: all_leads.count,
  #     today: all_leads.where("scanned_at >= ?", Time.zone.today.beginning_of_day).count,
  #     hot: all_leads.where(temperature: "hot").count,
  #     warm: all_leads.where(temperature: "warm").count,
  #     cold: all_leads.where(temperature: "cold").count,
  #     new_leads: all_leads.where(status: "new").count,
  #     interested: all_leads.where(status: "interested").count,
  #     follow_up: all_leads.where(status: "follow_up").count,
  #     converted: all_leads.where(status: "converted").count,
  #     follow_up_today: all_leads.where(follow_up_date: Date.current).count
  #   }
  # end

  private

  # Example:
  # event_code: EXP-2026-0003
  # stall_code: STL-EXP-2026-0003-0001
  def generate_stall_code
    return if stall_code.present?

    ev_code = event.event_code
    prefix = "STL-#{ev_code}"

    last_stall = StallOwner
                  .where("stall_code LIKE ?", "#{prefix}-%")
                  .order(stall_code: :desc)
                  .lock
                  .first

    sequence =
      if last_stall.present?
        last_stall.stall_code.split("-").last.to_i + 1
      else
        1
      end

    self.stall_code = format("%s-%04d", prefix, sequence)
  end

  def set_jti
    self.jti ||= SecureRandom.uuid
  end

  def initialize_analytics
    StallAnalytics.create!(
      stall_owner: self,
      event: event
    )
  end
end
