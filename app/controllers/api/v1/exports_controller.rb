module Api
  module V1
    class ExportsController < ApplicationController
      before_action :authenticate_any_user!

      def show
        job = ExportJob.find(params[:job_id])
        json_success({
          id:          job.id,
          status:      job.status,
          file_url:    job.file_url,
          export_type: job.export_type,
          error:       job.error_message,
          completed_at: job.completed_at,
          expires_at:  job.expires_at
        })
      end

      private

      def authenticate_any_user!
        token = extract_token
        return json_error("Unauthorized", status: :unauthorized) unless token

        payload = JWT.decode(
          token,
          ENV.fetch("DEVISE_JWT_SECRET_KEY", Rails.application.secret_key_base),
          true, { algorithm: "HS256" }
        ).first

        # Accept any role
        case payload["role"]
        when "stall_owner"   then @current_user = StallOwner.find_by(id: payload["sub"])
        when "organizer"     then @current_user = EventOrganizer.find_by(id: payload["sub"])
        when "super_admin"   then @current_user = SuperAdmin.find_by(id: payload["sub"])
        end

        json_error("Unauthorized", status: :unauthorized) unless @current_user
      rescue JWT::DecodeError
        json_error("Unauthorized", status: :unauthorized)
      end
    end
  end
end
