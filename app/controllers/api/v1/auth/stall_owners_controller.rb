module Api
  module V1
    module Auth
      class StallOwnersController < ApplicationController

        def sign_in
          mobile   = params[:mobile]&.strip
          password = params[:password]&.strip

          stall = ::StallOwner
            .where(mobile_number: mobile, pass_code: password)
            .order(:created_at)
            .first

          unless stall&.active?
            Rails.logger.warn(
              "Failed stall owner login for mobile: #{mobile}"
            )

            return json_error(
              "Invalid mobile number/password or account is inactive",
              status: :unauthorized
            )
          end

          token = stall.issue_token

          json_success({
            token: token,
            stall_owner: stall_response(stall),
            event: event_mini(stall.event)
          })
        end

        # POST /api/v1/stall/request_otp
        def request_otp
          mobile = params[:mobile_number]&.strip
          # event_id = params[:event_id]
          password = params[:password]

          # stall = ::StallOwner.find_by(mobile_number: mobile, event_id: event_id)
          stall = ::StallOwner.find_by(mobile_number: mobile, pass_code: password)
          return json_error("No account found with this mobile and password", status: :not_found) unless stall
          return json_error("Your account is inactive. Contact the event organizer.") unless stall.active?

          otp, = OtpVerification.generate_for(mobile, purpose: "stall_login", ip: request.remote_ip)
          SmsService.send_otp(mobile, otp)
          json_success({ message: "OTP sent to #{masked_phone(mobile)}" })
        end

        # POST /api/v1/stall/verify_otp
        def verify_otp
          mobile   = params[:mobile_number]&.strip
          otp_code = params[:otp]&.strip
          # event_id = params[:event_id]
          password = params[:password]

          result = OtpVerification.verify!(mobile, otp_code, purpose: "stall_login")

          case result
          when :valid
            stall = ::StallOwner.includes(:event).find_by!(mobile_number: mobile, pass_code: password)
            token = stall.issue_token
            json_success({
              token:       token,
              stall_owner: stall_response(stall),
              event:       event_mini(stall.event)
            })
          when :invalid, :not_found then json_error("Invalid OTP", status: :unauthorized)
          when :expired             then json_error("OTP expired. Request a new one.", status: :unauthorized)
          when :max_attempts        then json_error("Too many attempts. Try again later.", status: :too_many_requests)
          end
        end

        # DELETE /api/v1/stall/sign_out
        def sign_out
          authenticate_stall_owner!
          return if performed?
          @current_stall_owner.invalidate_token!
          json_success({ message: "Signed out" })
        end

        private

        def stall_response(s)
          { id: s.id, name: s.name, email: s.email, mobile_number: s.mobile_number,
            company_name: s.company_name, stall_number: s.stall_number,
            stall_category: s.stall_category, logo_url: s.logo_url,
            total_leads_count: s.total_leads_count, event_id: s.event_id }
        end

        def event_mini(e)
          { id: e.id, name: e.name, venue: e.venue,
            start_date: e.start_date, end_date: e.end_date, status: e.status }
        end

        def masked_phone(n); "#{n[0..1]}XXXXXX#{n[-2..]}"; end
      end
    end
  end
end
