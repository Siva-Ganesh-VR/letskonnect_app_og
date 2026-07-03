module Api
  module V1
    module Webhooks
      class TwilioController < ApplicationController
        # POST /api/v1/webhooks/twilio
        # Twilio delivery status callback
        def status
          message_sid    = params[:MessageSid]
          message_status = params[:MessageStatus]

          notification = Notification.find_by(external_message_id: message_sid)
          if notification
            case message_status
            when "delivered"
              notification.update!(status: "delivered", delivered_at: Time.current)
            when "failed", "undelivered"
              notification.update!(status: "failed", error_message: params[:ErrorMessage])
            end
          end

          head :ok
        end

        def receive
          from = params["From"].to_s
          body = params["Body"].to_s.strip

          mobile_number = from.delete_prefix("whatsapp:").delete_prefix("+91")

          event_id = body[/EVENT_ID:([a-f0-9\-]+)/i, 1]

          if event_id.present?
            visitor = Visitor.find_or_initialize_by(
              mobile_number: mobile_number,
              event_id: event_id
            )

            if visitor.new_record?
              visitor.assign_attributes(
                whatsapp_state: "start",
                mobile_verified: true,
                active: true
              )

              visitor.save!(validate: false)
            elsif visitor.whatsapp_state == "completed"
              WhatsappService.send_message(
                mobile_number,
                "You are already registered for this event."
              )

              return head :ok
            end

            # Remove EVENT_ID from the message before passing it to the flow
            body = body.sub(/EVENT_ID:[a-f0-9\-]+/i, "").strip
          else
            visitor = Visitor.where(
              mobile_number: mobile_number
            ).where.not(
              whatsapp_state: "completed"
            ).order(created_at: :desc)
            .first
          end

          return head :ok unless visitor

          WhatsappFlowService.new(visitor, body).process

          head :ok
        end
      end
    end
  end
end
