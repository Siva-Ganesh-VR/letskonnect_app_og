class SuperAdmin < ApplicationRecord
  has_secure_password

  has_many :event_organizers, dependent: :nullify

  validates :name,  presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: /\A[^@\s]+@[^@\s]+\z/ }

  before_create :set_jti

  def issue_token
    ApplicationController.issue_token(sub: id, role: "super_admin", jti: jti)
  end

  private
  def set_jti; self.jti ||= SecureRandom.uuid; end
end
