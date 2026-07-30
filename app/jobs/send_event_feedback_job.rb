class SendEventFeedbackJob < ApplicationJob
  queue_as :default

  REMINDER_AFTER = 3.days

  def perform
    Event.where(status: "done").find_each do |event|
      event.visitors
           .where(
             whatsapp_state: "completed",
             mobile_verified: true
           )
           .find_each do |visitor|

        next if feedback_given?(event.id, visitor.id)
        next unless should_send_feedback?(visitor)

        begin
          WhatsappService.send_feedback_link(visitor)

          visitor.update!(
            feedback_sent_at: Time.current
          )

          Rails.logger.info(
            "Feedback link sent to visitor #{visitor.id} for event #{event.id}"
          )
        rescue => e
          Rails.logger.error(
            "Failed to send feedback link to visitor #{visitor.id}: #{e.class} - #{e.message}"
          )
        end
      end
    end
  end

  private

  def should_send_feedback?(visitor)
    visitor.feedback_sent_at.nil? ||
      visitor.feedback_sent_at <= REMINDER_AFTER.ago
  end

  def feedback_given?(event_id, visitor_id)
    Feedback.exists?(
      event_id: event_id,
      visitor_id: visitor_id
    )
  end
end