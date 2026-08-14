# Add this to routes.rb OUTSIDE the super_admin namespace
# so frontend can POST without auth token:
#
#   post "error_logs", to: "api/v1/error_logs#create"
#
# Then create this controller:

# app/controllers/api/v1/error_logs_controller.rb
module Api
  module V1
    class ErrorLogsController < ApplicationController
      # No authentication — frontend posts here without token
      skip_before_action :authenticate_super_admin!, raise: false
      skip_before_action :authenticate_organizer!,   raise: false
      skip_before_action :authenticate_stall_owner!, raise: false

      # POST /api/v1/error_logs
      # Called by frontend_error_logging.js via sendBeacon
      def create
        ErrorLog.capture(
          message:    params[:message].to_s.truncate(2000),
          source:     "frontend",
          severity:   params[:severity].presence_in(["error","warning","info"]) || "error",
          error_type: params[:error_type],
          endpoint:   params[:page_url],
          user_agent: params[:user_agent]&.truncate(300),
          ip_address: request.remote_ip,
          user_type:  params[:user_type],
          context:    params[:context],
        )

        head :ok
      rescue => e
        Rails.logger.error("[ErrorLog] Frontend log failed: #{e.message}")
        head :ok  # Always return 200 — never error on error logging
      end
    end
  end
end
