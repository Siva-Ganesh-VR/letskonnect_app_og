module Api
  module V1
    class ScansController < ApplicationController
      def show_visitor
        visitor = Visitor.includes(:event).find_by(qr_token: params[:qr_token])
        return json_error("Invalid QR code", status: :not_found) unless visitor
        return json_error("Visitor not verified") unless visitor.mobile_verified?

        json_success({
          visitor_id_code:   visitor.visitor_id_code,
          full_name:         visitor.full_name,
          mobile_number:     visitor.mobile_number,
          business_name:     visitor.business_name,
          business_category: visitor.business_category,
          profession:        visitor.profession,
          location:          visitor.location,
          event_name:        visitor.event.name
        })
      end
    end
  end
end
