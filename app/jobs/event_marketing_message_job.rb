class EventMarketingMessageJob < ApplicationJob
  queue_as :default

  def perform(visitor_id = nil)
    if visitor_id.present?
      send_to_visitor(Visitor.find_by(id: visitor_id))
    else
      send_pending_messages
    end
  end

  private

  def send_pending_messages
    Event.active.find_each do |event|
      event.visitors.where(active: true, mobile_verified: true).find_each do |visitor|
        send_to_visitor(visitor)
      end
    end
  end

  def send_to_visitor(visitor)
    return unless visitor
    return unless visitor.active? && visitor.mobile_verified?

    event = visitor.event
    template = event.message_template || Template.default_message_template
    return unless template

    return if VisitorMessageDelivery.exists?(event: event, visitor: visitor)

    response = WhatsappService.send_event_marketing_message(visitor)

    VisitorMessageDelivery.create!(
      event: event,
      visitor: visitor,
      template: template,
      twilio_message_sid: response[:sid],
      status: response[:success] ? "sent" : "failed",
      sent_at: response[:success] ? Time.current : nil,
      failed_at: response[:success] ? nil : Time.current,
      error_message: response[:error],
      message_type: "marketing"
    )
  end
end