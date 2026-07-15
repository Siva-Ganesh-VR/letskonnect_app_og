class EventStatusUpdateJob < ApplicationJob
  queue_as :scheduled

  def perform
    Rails.logger.info("[EventStatusUpdate] Starting event status update")

    Event.where("end_date < ?", Time.current).where.not(status: [:done, :not_published]).find_each do |event|
      case event.status
      when "active"
        event.update!(status: :done)
      when "draft"
        event.update!(status: :not_published)
      end
    end

    Rails.logger.info("[EventStatusUpdate] Completed")
  end
end