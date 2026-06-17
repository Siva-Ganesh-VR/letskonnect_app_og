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
      end
    end
  end
end
