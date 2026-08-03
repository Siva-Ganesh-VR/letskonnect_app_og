module Api
  module V1
    module Auth
      class VisitorsController < ApplicationController
        # POST /api/v1/visitors/register
        def create
          event = Event.find_by(registration_qr_token: params[:event_token])

          return json_error(
            "Invalid event QR code",
            status: :not_found
          ) unless event

          return json_error(
            "Event registration is not open",
            status: :forbidden
          ) unless event.active?

          if event.max_visitors.present? && event.registered_count >= event.max_visitors
            return json_error(
              "Event has reached maximum visitor capacity",
              status: :forbidden
            )
          end

          mobile_number = params.dig(:visitor, :mobile_number)

          existing = Visitor.find_by(
            mobile_number: mobile_number,
            event_id: event.id
          )

          if existing&.mobile_verified?
            return json_error(
              "This mobile number is already registered for this event. Please use your existing QR code."
            )
          end

          questions = params.dig(:visitor, :questions) || {}

          ActiveRecord::Base.transaction do
            visitor = existing || Visitor.new(
              visitor_params.merge(event: event)
            )

            visitor.assign_attributes(visitor_params) if existing

            visitor.assign_attributes(
              mobile_verified: true,
              active: true,
              whatsapp_state: "start",
              send_registration_whatsapp: true
            )

            visitor.save!

            save_visitor_answers(visitor, questions)

            json_success(
              {
                visitor_id: visitor.id,
                visitor_id_code: visitor.visitor_id_code,
                full_name: visitor.full_name,
                mobile_number: visitor.mobile_number,
                location: visitor.location,
                profession: visitor.profession,
                business_category: visitor.business_category,
                business_name: visitor.business_name,
                designation: visitor.designation,
                email: visitor.email,
                qr_image_url: visitor.qr_image_url
              },
              status: :created
            )
          end

        rescue ActiveRecord::RecordInvalid => e
          json_error(
            "Registration failed",
            errors: e.record.errors.full_messages
          )
        end

        # POST /api/v1/visitors/verify_otp
        def verify_otp
          visitor = Visitor.includes(:event).find_by(id: params[:visitor_id])
          return json_error("Visitor not found", status: :not_found) unless visitor
          return json_error("Already verified. Please use your existing QR code.") if visitor.mobile_verified?

          unless visitor.valid_otp?(params[:otp])
            return json_error("Invalid or expired OTP. Please request a new one.", status: :unauthorized)
          end

          visitor.verify_mobile!

          json_success({
            visitor:      visitor_response(visitor),
            digital_pass: digital_pass_data(visitor),
            event:        event_summary(visitor.event)
          })
        end

        # POST /api/v1/visitors/resend_otp
        def resend_otp
          visitor = Visitor.find_by(id: params[:visitor_id])
          return json_error("Visitor not found", status: :not_found) unless visitor
          return json_error("Already verified") if visitor.mobile_verified?

          otp = visitor.generate_otp!
          SmsService.send_otp(visitor.mobile_number, otp)
          json_success({ message: "OTP resent to #{masked_phone(visitor.mobile_number)}" })
        end

        # GET /api/v1/visitors/dashboard/:id
        def dashboard
          visitor = Visitor.includes(:event, leads: :stall_owner).find(params[:id])
          return json_error("Visitor not verified", status: :forbidden) unless visitor.mobile_verified?

          json_success({
            visitor:        visitor_response(visitor),
            event:          event_summary(visitor.event),
            stalls_visited: visitor.leads.map { |l| stall_visit_data(l) },
            qr_code_url:    visitor.qr_image_url
          })
        end

        # GET /api/v1/visitors/qr/:id
        def qr_code
          visitor = Visitor.find(params[:id])
          return json_error("Not verified", status: :forbidden) unless visitor.mobile_verified?
          json_success({ qr_token: visitor.qr_token, qr_image_url: visitor.qr_image_url, display_url: visitor.display_qr_url })
        end

        def save_visitor_answers(visitor, questions)
          template_id = visitor.event.template_id
          template = if template_id.present?
                  Template.find_by(
                    id: template_id,
                    template_type: "question",
                    active: true
                  )
                else
                  Template.find_by(
                    template_type: "question",
                    is_default: true,
                    active: true
                  )
                end

          return if template.blank?

          valid_question_ids = template.template_questions.pluck(:id).map(&:to_s)

          questions.each do |question_key, answer|
            question_key = question_key.to_s

            next unless valid_question_ids.include?(question_key)

            answer_value =
              if answer.is_a?(Array)
                answer.join(", ")
              else
                answer.to_s
              end

            next if answer_value.blank?

            visitor.visitor_answers.create!(
              question_key: question_key,
              answer: answer_value
            )
          end
        end

        private

        def visitor_params
          params.require(:visitor).permit(
            :full_name, :mobile_number, :location, :profession,
            :business_category, :business_name, :designation, :email, :website
          )
        end

        def visitor_response(v)
          {
            id:                v.id,
            visitor_id_code:   v.visitor_id_code,
            full_name:         v.full_name,
            mobile_number:     v.mobile_number,
            email:             v.email,
            profession:        v.profession,
            business_name:     v.business_name,
            business_category: v.business_category,
            location:          v.location,
            designation:       v.designation,
            qr_token:          v.qr_token,
            qr_image_url:      v.qr_image_url,
            registered_at:     v.created_at.iso8601
          }
        end

        def digital_pass_data(v)
          {
            event_name:    v.event.name,
            event_venue:   v.event.venue,
            event_city:    v.event.city,
            start_date:    v.event.start_date.strftime("%b %d, %Y"),
            end_date:      v.event.end_date.strftime("%b %d, %Y"),
            visitor_name:  v.full_name,
            visitor_id:    v.visitor_id_code,
            qr_code_url:   v.qr_image_url,
            display_url:   v.display_qr_url
          }
        end

        def event_summary(e)
          {
            id:          e.id,
            name:        e.name,
            venue:       e.venue,
            city:        e.city,
            start_date:  e.start_date,
            end_date:    e.end_date,
            banner_url:  e.banner_url,
            stall_count: e.stall_owners.active.count
          }
        end

        def stall_visit_data(lead)
          {
            company_name:  lead.stall_owner.company_name,
            stall_number:  lead.stall_owner.stall_number,
            category:      lead.stall_owner.stall_category,
            visited_at:    lead.scanned_at.iso8601
          }
        end

        def masked_phone(number)
          "#{number[0..1]}XXXXXX#{number[-2..]}"
        end
      end
    end
  end
end
