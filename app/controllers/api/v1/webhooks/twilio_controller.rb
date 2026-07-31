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

          event_code = body[/EVENT_CODE:([A-Za-z0-9-]+)/i, 1]
          bni_event_code = body[/BNI_EVENT_CODE:([A-Za-z0-9-]+)/i, 1]
          is_bni = bni_event_code.present?

          if event_code.present? || bni_event_code.present?
            code = bni_event_code.presence || event_code

            event = Event.find_by(event_code: code)

            unless event
              WhatsappService.send_message(
                mobile_number,
                "❌ Invalid event code. Please scan the event QR code again to start your registration."
              )

              return head :ok
            end

            visitor = Visitor.find_or_initialize_by(
              mobile_number: mobile_number,
              event_id: event.id
            )

            if visitor.new_record?
              visitor.assign_attributes(
                whatsapp_state: "start",
                mobile_verified: true,
                active: true
              )
              visitor.reg_type = "VIP QR Scan" if is_bni

              visitor.save!(validate: false)
            elsif visitor.whatsapp_state == "completed"
              WhatsappService.send_message(
                mobile_number,
                "You are already registered for this event."
              )

              return head :ok
            end

            # Remove EVENT_CODE from the message before passing it to the flow
            body = body.sub(/EVENT_CODE:([A-Za-z0-9-]+)/i, "").sub(/BNI_EVENT_CODE:[A-Za-z0-9-]+/i, "").strip
          else
            visitor = Visitor.where(
              mobile_number: mobile_number
            ).where.not(
              whatsapp_state: "completed"
            ).order(created_at: :desc)
            .first
          end

          unless visitor
            WhatsappService.send_message(
              mobile_number,
              "❌ Invalid or expired registration session. Please scan the event QR code again to start your registration."
            )

            return head :ok
          end

          if is_bni
            BniWhatsappFlowService.new(visitor, body).process
          elsif visitor.whatsapp_state.start_with?("bni_")
            BniWhatsappFlowService.new(visitor, body).process
          else
            WhatsappFlowService.new(visitor, body).process
          end

          head :ok
        end

      end
    end
  end
end
