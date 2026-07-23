class ApplicationController < ActionController::API
  include Pagy::Backend

  rescue_from ActiveRecord::RecordNotFound,       with: :not_found
  rescue_from ActiveRecord::RecordInvalid,        with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  # ─── Response helpers ────────────────────────────────────────────────────

  def json_success(data = {}, status: :ok, meta: {})
    resp = { success: true, data: data }
    resp[:meta] = meta if meta.present?

    # Log payload size for production debugging. To log full JSON body set
    # request header `X-Debug-Json: true` or run in development environment.
    begin
      payload = resp.to_json
      Rails.logger.info("json_success payload_size=#{payload.bytesize}")
      if Rails.env.development? || request&.headers&.[]('X-Debug-Json') == 'true'
        Rails.logger.debug("json_success payload=#{payload}")
      end
    rescue StandardError => e
      Rails.logger.error("json_success logging failed: #{e.message}")
    end

    render json: resp, status: status
  end

  def json_error(message, status: :unprocessable_entity, errors: nil)
    resp = { success: false, error: message }
    resp[:errors] = errors if errors.present?
    render json: resp, status: status
  end

  # ─── JWT helpers ──────────────────────────────────────────────────────────

  JWT_SECRET = -> { ENV.fetch("JWT_SECRET_KEY", "stallconnect_dev_secret_change_in_prod_#{Rails.application.secret_key_base[0..15]}") }
  JWT_ALGO   = "HS256"

  def self.issue_token(payload)
    base = { iat: Time.current.to_i, exp: 30.days.from_now.to_i }
    JWT.encode(base.merge(payload), JWT_SECRET.call, JWT_ALGO)
  end

  def decode_token(token)
    JWT.decode(token, JWT_SECRET.call, true, { algorithm: JWT_ALGO }).first
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end

  def extract_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")
    header.split(" ", 2).last
  end

  # ─── Auth guards ──────────────────────────────────────────────────────────

  def authenticate_stall_owner!
    payload = decode_token(extract_token)
    return json_error("Unauthorized", status: :unauthorized) unless payload
    return json_error("Unauthorized", status: :unauthorized) unless payload["role"] == "stall_owner"

    @current_stall_owner = StallOwner.find_by(id: payload["sub"])
    return json_error("Unauthorized", status: :unauthorized) unless @current_stall_owner&.active?
    return json_error("Session expired, please login again", status: :unauthorized) if @current_stall_owner.jti != payload["jti"]
  end

  def authenticate_organizer!
    payload = decode_token(extract_token)
    return json_error("Unauthorized", status: :unauthorized) unless payload
    return json_error("Unauthorized", status: :unauthorized) unless payload["role"] == "organizer"

    @current_organizer = EventOrganizer.find_by(id: payload["sub"])
    return json_error("Unauthorized", status: :unauthorized) unless @current_organizer&.active?
  end

  def authenticate_super_admin!
    payload = decode_token(extract_token)
    return json_error("Unauthorized", status: :unauthorized) unless payload
    return json_error("Unauthorized", status: :unauthorized) unless payload["role"] == "super_admin"

    @current_super_admin = SuperAdmin.find_by(id: payload["sub"])
    return json_error("Unauthorized", status: :unauthorized) unless @current_super_admin
  end

  # ─── Standard error handlers ─────────────────────────────────────────────

  def not_found(e)
    json_error("Not found: #{e.message}", status: :not_found)
  end

  def unprocessable_entity(e)
    render json: { success: false, errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def bad_request(e)
    json_error(e.message, status: :bad_request)
  end
end
