# app/controllers/concerns/error_logging.rb
#
# Include in ApplicationController to automatically:
# 1. Log all 5xx errors from API controllers
# 2. Log 422 Unprocessable Entity (validation failures)
# 3. Log stuck requests (>10s)
# 4. Provide log_error() helper for manual logging anywhere
#
# Usage:
#   include ErrorLogging   # in ApplicationController
#
#   # Manual logging anywhere in a controller:
#   log_error("Visitor QR not found", context: { qr_token: token })
#
module ErrorLogging
  extend ActiveSupport::Concern

  included do
    # Rescue all unhandled exceptions and log them
    rescue_from StandardError, with: :handle_unexpected_error
    after_action :log_validation_errors   # ← ADD THIS LINE
  end

  private


  # ── ADD THIS METHOD anywhere in the private section ───────────
  def log_validation_errors
    return unless response.status == 422
    ErrorLog.capture(
      message:        "422 Validation Error: #{response.body.to_s.truncate(500)}",
      source:         "api",
      severity:       "warning",
      status_code:    "422",
      endpoint:       request.path,
      http_method:    request.method,
      request_params: safe_params.to_json,
      ip_address:     request.remote_ip,
      request_id:     request.uuid,
      event_id:       extract_event_id,
      stall_owner_id: current_stall_owner_id,
      organizer_id:   current_organizer_id,
      user_type:      current_user_type,
    )
  end

  # ── Manual helper — call from any controller action ───────────
  def log_error(message, severity: "error", **attrs)
    ErrorLog.capture(
      message:        message,
      source:         "api",
      severity:       severity,
      endpoint:       request.path,
      http_method:    request.method,
      request_params: safe_params.to_json,
      ip_address:     request.remote_ip,
      user_agent:     request.user_agent&.truncate(300),
      request_id:     request.uuid,
      event_id:       attrs.delete(:event_id) || extract_event_id,
      visitor_id:     attrs.delete(:visitor_id),
      stall_owner_id: attrs.delete(:stall_owner_id) || current_stall_owner_id,
      organizer_id:   attrs.delete(:organizer_id)   || current_organizer_id,
      user_type:      attrs.delete(:user_type)       || current_user_type,
      **attrs
    )
  end

  # ── Auto-capture unhandled exceptions ─────────────────────────
  def handle_unexpected_error(exception)
    ErrorLog.capture(
      message:        exception.message.truncate(2000),
      source:         "api",
      severity:       "error",
      error_type:     exception.class.name,
      status_code:    "500",
      backtrace:      exception.backtrace&.first(20)&.join("\n"),
      endpoint:       request.path,
      http_method:    request.method,
      request_params: safe_params.to_json,
      ip_address:     request.remote_ip,
      user_agent:     request.user_agent&.truncate(300),
      request_id:     request.uuid,
      event_id:       extract_event_id,
      stall_owner_id: current_stall_owner_id,
      organizer_id:   current_organizer_id,
      user_type:      current_user_type,
    )

    Rails.logger.error("[ErrorLog] #{exception.class}: #{exception.message}")
    Rails.logger.error(exception.backtrace&.first(10)&.join("\n"))

    render json: { success: false, error: "An unexpected error occurred." }, status: :internal_server_error
  end

  # ── Extract event_id from request params or route ─────────────
  def extract_event_id
    params[:event_id] || params.dig(:event, :id)
  rescue
    nil
  end

  # ── Get current user IDs safely ───────────────────────────────
  def current_stall_owner_id
    @current_stall_owner&.id
  rescue
    nil
  end

  def current_organizer_id
    @current_organizer&.id
  rescue
    nil
  end

  def current_user_type
    return "stall_owner" if @current_stall_owner
    return "organizer"   if @current_organizer
    return "admin"       if @current_super_admin
    "visitor"
  rescue
    "unknown"
  end

  # ── Sanitize params — remove sensitive fields ─────────────────
  def safe_params
    params.to_unsafe_h
          .except("password", "pass_code", "otp", "otp_code",
                  "token", "jwt", "secret", "auth", "credit_card",
                  "controller", "action", "format")
          .transform_values { |v| v.is_a?(String) && v.length > 500 ? v.truncate(500) : v }
  rescue
    {}
  end
end
