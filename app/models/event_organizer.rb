class EventOrganizer < ApplicationRecord
  has_secure_password

  belongs_to :super_admin
  has_many :events, dependent: :destroy
  has_many :stall_owners, through: :events

  validates :name, :email, :mobile_number, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                    format: { with: /\A[^@\s]+@[^@\s]+\z/ }
  validates :mobile_number, format: { with: /\A[6-9]\d{9}\z/, message: "must be valid 10-digit Indian mobile" }

  before_create :set_jti

  scope :active, -> { where(active: true) }

  def issue_token
    ApplicationController.issue_token(sub: id, role: "organizer", jti: jti)
  end

  private
  def set_jti; self.jti ||= SecureRandom.uuid; end
end
