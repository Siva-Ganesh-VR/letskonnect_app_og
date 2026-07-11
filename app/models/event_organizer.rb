class EventOrganizer < ApplicationRecord
  include MobileFormattable
  has_secure_password

  belongs_to :super_admin
  has_many :events, dependent: :destroy
  has_many :stall_owners, through: :events

  validates :name, :email, :mobile_number, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                    format: { with: /\A[^@\s]+@[^@\s]+\z/ }
  validates :mobile_number, format: { with: /\A[6-9]\d{9}\z/,
                            message: "must be valid 10-digit Indian mobile" }
  validates :org_code, uniqueness: true, allow_nil: true   # ← NEW

  before_create :set_jti
  before_create :generate_org_code                         # ← NEW

  scope :active, -> { where(active: true) }

  def issue_token
    ApplicationController.issue_token(sub: id, role: "organizer", jti: jti)
  end

  private

  # Generates ORG-YYYY-XXXX — race-condition safe via SELECT FOR UPDATE
  def generate_org_code
    year = Time.current.year

    last = EventOrganizer
             .where("org_code LIKE ?", "ORG-#{year}-%")
             .order(:org_code)
             .lock
             .last

    next_seq = last ? last.org_code.split("-").last.to_i + 1 : 1
    self.org_code = format("ORG-%d-%04d", year, next_seq)
  end

  def set_jti
    self.jti ||= SecureRandom.uuid
  end
end

