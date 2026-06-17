class RegistrationsController < ActionController::Base
  layout false

  def show
    @event = Event.find_by(registration_qr_token: params[:event_token])
    if @event.nil?
      render plain: "Invalid event QR code", status: :not_found and return
    end
    unless @event.active?
      render plain: "Event registration is closed", status: :forbidden and return
    end
    render :show
  end
end
