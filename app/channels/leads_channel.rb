class LeadsChannel < ApplicationCable::Channel
  def subscribed
    stall_owner = authenticate_stall_owner!
    if stall_owner
      stream_from "leads_#{stall_owner.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  private

  def authenticate_stall_owner!
    token = params[:token]
    return nil unless token
    payload = JWT.decode(
      token,
      ENV.fetch("DEVISE_JWT_SECRET_KEY", Rails.application.secret_key_base),
      true, { algorithm: "HS256" }
    ).first
    stall = StallOwner.find_by(id: payload["sub"])
    return nil unless stall&.active? && stall.jti == payload["jti"]
    stall
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound
    nil
  end
end
