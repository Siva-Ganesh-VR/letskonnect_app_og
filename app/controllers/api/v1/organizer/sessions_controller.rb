module Api
  module V1
    module Organizer
      class SessionsController < ApplicationController
        # POST /api/v1/organizer/sign_in
        def create
          Rails.logger.info("Attempting to sign in organizer with email: #{params[:email]}")

          organizer = EventOrganizer.find_by(email: params[:email]&.strip&.downcase)
          unless organizer&.authenticate(params[:password]) && organizer.active?
            Rails.logger.warn("Failed to sign in organizer with email: #{params[:email]}")
            return json_error("Invalid email/password or account is inactive", status: :unauthorized)
          end
          json_success({ token: organizer.issue_token, organizer: organizer_resp(organizer) })
        end

        # DELETE /api/v1/organizer/sign_out
        def destroy
          authenticate_organizer!
          return if performed?
          json_success({ message: "Signed out" })
        end

        private
        def organizer_resp(o)
          { id: o.id, name: o.name, email: o.email,
            company_name: o.company_name, mobile_number: o.mobile_number }
        end
      end
    end
  end
end
