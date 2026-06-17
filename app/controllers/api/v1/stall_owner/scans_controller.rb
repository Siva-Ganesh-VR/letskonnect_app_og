module Api
  module V1
    module StallOwner
      class ScansController < ApplicationController
        before_action :authenticate_stall_owner!

        # POST /api/v1/stall_owner/scan
        def create
          qr_token = params[:qr_token]&.strip
          return json_error("QR token is required") if qr_token.blank?

          visitor = Visitor.includes(:event).find_by(qr_token: qr_token)
          return json_error("Invalid QR code. This visitor does not exist.", status: :not_found) unless visitor
          return json_error("Visitor has not completed registration.") unless visitor.mobile_verified?

          unless visitor.event_id == @current_stall_owner.event_id
            return json_error("This QR code belongs to a different event.", status: :forbidden)
          end

          # Check for duplicate scan
          existing_lead = Lead.find_by(visitor_id: visitor.id, stall_owner_id: @current_stall_owner.id)
          if existing_lead
            return json_success({
              already_scanned: true,
              lead:    lead_response(existing_lead),
              visitor: visitor_scan_data(visitor),
              message: "This visitor was already scanned at #{existing_lead.scanned_at.strftime('%I:%M %p')}"
            })
          end

          lead = Lead.create!(
            visitor:     visitor,
            stall_owner: @current_stall_owner,
            event:       @current_stall_owner.event,
            scanned_at:  Time.current,
            temperature: "warm",
            interest_rating: 3,
            status:      "new"
          )

          json_success({
            already_scanned: false,
            lead:    lead_response(lead),
            visitor: visitor_scan_data(visitor),
            message: "Lead captured successfully!"
          }, status: :created)
        end

        # GET /api/v1/stall_owner/scan/history
        def history
          scans = @current_stall_owner.leads.includes(:visitor)
                    .order(scanned_at: :desc).limit(50).map do |l|
            { visitor_name: l.visitor.full_name, business: l.visitor.business_name,
              temperature: l.temperature, scanned_at: l.scanned_at.iso8601 }
          end
          json_success(scans)
        end

        # GET /api/v1/scan/:qr_token  (public — returns visitor info for scan preview)
        def show_visitor
          visitor = Visitor.includes(:event).find_by(qr_token: params[:qr_token])
          return json_error("Invalid QR code", status: :not_found) unless visitor
          return json_error("Visitor not verified") unless visitor.mobile_verified?

          json_success(visitor_scan_data(visitor).merge(event_name: visitor.event.name))
        end

        private

        def visitor_scan_data(v)
          {
            id:                v.id,
            visitor_id_code:   v.visitor_id_code,
            full_name:         v.full_name,
            mobile_number:     v.mobile_number,
            location:          v.location,
            profession:        v.profession,
            business_name:     v.business_name,
            business_category: v.business_category,
            designation:       v.designation,
            email:             v.email,
            website:           v.website
          }
        end

        def lead_response(l)
          { id: l.id, temperature: l.temperature, status: l.status,
            interest_rating: l.interest_rating, notes: l.notes,
            follow_up_date: l.follow_up_date, scanned_at: l.scanned_at.iso8601 }
        end
      end
    end
  end
end
