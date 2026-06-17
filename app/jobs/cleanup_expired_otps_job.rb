class CleanupExpiredOtpsJob < ApplicationJob
  queue_as :scheduled

  def perform
    deleted = OtpVerification.where("expires_at < ?", 1.hour.ago).delete_all
    Rails.logger.info("[Cleanup] Deleted #{deleted} expired OTP records")
  end
end
