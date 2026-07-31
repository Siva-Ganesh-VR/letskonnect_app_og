class PreRegistrationsController < ActionController::Base
  layout false

  def show
    @event = Event.find_by(registration_qr_token: params[:event_token])
    if @event.nil?
      render plain: "Invalid event QR code", status: :not_found and return
    end
    unless @event.active?
      render plain: "Event registration is closed", status: :forbidden and return
    end
    @template = @event.template || Template.find_by(template_type: "question", is_default: true)
    
    render :show
  end

end