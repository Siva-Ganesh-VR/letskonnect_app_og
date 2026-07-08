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

          unless visitor.event_id == selected_stall_owner.event_id
            return json_error("This QR code belongs to a different event.", status: :forbidden)
          end

          # Check for duplicate scan
          existing_lead = Lead.find_by(visitor_id: visitor.id, stall_owner_id: selected_stall_owner.id)
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
            stall_owner: selected_stall_owner,
            event:       selected_stall_owner.event,
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
          scans = selected_stall_owner.leads.includes(:visitor)
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

        def manual_create_lead
          event = Event.find_by(id: params[:event_id])
          return json_error("Invalid event", status: :not_found) unless event
          return json_error("Event registration is not open", status: :forbidden) unless event.active?

          if event.max_visitors.present? && event.registered_count >= event.max_visitors
            return json_error("Event has reached maximum visitor capacity", status: :forbidden)
          end

          stall_owner = selected_stall_owner

          visitor = Visitor.find_or_initialize_by(
            mobile_number: visitor_params[:mobile_number],
            event_id: event.id
          )

          if visitor.persisted? && visitor.mobile_verified?
            return json_error(
              "This mobile number is already registered for this event. Please use your existing QR code."
            )
          end

          visitor.assign_attributes(visitor_params)
          visitor.event = event
          visitor.reg_type = "Manual"
          visitor.mobile_verified = true

          ActiveRecord::Base.transaction do
            visitor.save!

            WhatsappNotificationJob.perform_later(visitor.id, "visitor_registration")

            lead = Lead.find_by(visitor_id: visitor.id, stall_owner_id: stall_owner.id)

            if lead
              return json_success(
                {
                  already_scanned: true,
                  lead: lead_response(lead),
                  visitor: visitor_scan_data(visitor),
                  message: "This visitor was already scanned at #{lead.scanned_at.strftime('%I:%M %p')}"
                }
              )
            end

            lead = Lead.create!(
              visitor: visitor,
              stall_owner: stall_owner,
              event: event,
              scanned_at: Time.current,
              temperature: "warm",
              interest_rating: 3,
              status: "new",
              reg_type: "Manual",
              notes: params[:notes]
            )

            json_success(
              {
                already_scanned: false,
                lead: lead_response(lead),
                visitor: visitor_scan_data(visitor),
                message: "Lead captured successfully!"
              },
              status: :created
            )
          end

        rescue ActiveRecord::RecordInvalid => e
          json_error(e.record.errors.full_messages.join(", "), status: :unprocessable_entity)
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

        def selected_stall_owner
          @selected_stall_owner ||= ::StallOwner.find_by(
            mobile_number: @current_stall_owner.mobile_number,
            event_id: params[:event_id]
          ) || @current_stall_owner
        end

        def visitor_params
          params.require(:visitor).permit(
            :full_name, :mobile_number, :location, :profession,
            :business_category, :business_name, :designation, :email, :website, :reg_type,
            :looking_for, :decision_maker, :mobile_verified
          )
        end
      end
    end
  end
end
