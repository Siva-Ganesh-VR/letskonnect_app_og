class SendEventFeedbackJob < ApplicationJob
  queue_as :default

  def perform
    Event
      .where(status: "done")
      .find_each do |event|

      event.visitors
        .where(
          whatsapp_state: "completed",
          mobile_verified: true,
          feedback_sent_at: nil
        )
        .find_each do |visitor|

        begin
          WhatsappService.send_feedback_link(visitor)

          visitor.update!(
            feedback_sent_at: Time.current
          )

          Rails.logger.info(
            "Feedback link sent to visitor #{visitor.id} " \
            "for event #{event.id}"
          )
        rescue => e
          Rails.logger.error(
            "Failed to send feedback link to visitor #{visitor.id}: " \
            "#{e.class} - #{e.message}"
          )
        end

      end
    end
  end
end