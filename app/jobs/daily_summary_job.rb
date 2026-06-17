class DailySummaryJob < ApplicationJob
  queue_as :scheduled

  def perform
    Rails.logger.info("[DailySummary] Starting daily summary job")
    Event.active_events.each do |event|
      event.stall_owners.active.each do |stall_owner|
        summary = stall_owner.dashboard_summary
        next if summary[:today].zero?
        WhatsappService.send_daily_summary(stall_owner, summary)
        sleep(0.1) # gentle rate limiting
      end
    end
    Rails.logger.info("[DailySummary] Completed")
  end
end
