class UpdateLeadAnalyticsJob < ApplicationJob
  queue_as :analytics

  def perform(stall_owner_id, event_id)
    AnalyticsService.update_stall_analytics(stall_owner_id, event_id)
    AnalyticsService.update_event_analytics(event_id)
  rescue => e
    Rails.logger.error("[Analytics Job] #{e.message}")
  end
end
