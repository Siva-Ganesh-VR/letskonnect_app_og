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

          if event_code.present?
            event = Event.find_by(event_code: event_code)

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

          unless visitor
            WhatsappService.send_message(
              mobile_number,
              "❌ Invalid or expired registration session. Please scan the event QR code again to start your registration."
            )

            return head :ok
          end

          WhatsappFlowService.new(visitor, body).process

          head :ok
        end

        def status
          sid = params[:MessageSid].to_s
          status = params[:MessageStatus].to_s.downcase

          delivery = VisitorMessageDelivery.find_by(twilio_message_sid: sid)

          unless delivery
            Rails.logger.warn("Twilio Status Callback: Unknown SID #{sid}")
            return head :ok
          end

          update_attrs = {
            status: status
          }

          case status
          when "queued"
            # Nothing to update

          when "accepted"
            # Nothing to update

          when "sending"
            # Nothing to update

          when "sent"
            update_attrs[:sent_at] ||= Time.current

          when "delivered"
            update_attrs[:sent_at] ||= Time.current
            update_attrs[:delivered_at] ||= Time.current

          when "read"
            update_attrs[:sent_at] ||= Time.current
            update_attrs[:delivered_at] ||= Time.current
            update_attrs[:read_at] ||= Time.current

          when "failed", "undelivered"
            update_attrs[:failed_at] = Time.current
            update_attrs[:error_message] =
              [
                params[:ErrorCode],
                params[:ErrorMessage]
              ].compact.join(" - ")

          end

          delivery.update!(update_attrs)

          head :ok
        end

        private

        def delivered_time(status)
          return Time.current if %w[delivered read].include?(status)

          nil
        end
      end
    end
  end
end
