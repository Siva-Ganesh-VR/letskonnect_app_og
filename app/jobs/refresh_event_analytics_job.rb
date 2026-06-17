class RefreshEventAnalyticsJob < ApplicationJob
  queue_as :scheduled

  def perform
    Event.active_events.each do |event|
      AnalyticsService.update_event_analytics(event.id)
    rescue => e
      Rails.logger.error("[Analytics Refresh] Event #{event.id}: #{e.message}")
    end
  end
end
