class RegistrationsController < ActionController::Base
  layout false

  # def show
  #   @event = Event.find_by(registration_qr_token: params[:event_token])
  #   if @event.nil?
  #     render plain: "Invalid event QR code", status: :not_found and return
  #   end
  #   unless @event.active?
  #     render plain: "Event registration is closed", status: :forbidden and return
  #   end
  #   render :show
  # end

  def show
    event = Event.find_by!(registration_qr_token: params[:event_token])
    case handle_event_access(event)
    when "invalid"
      redirect_to whatsapp_fallback_message("Invalid event QR code") and return

    when "closed"
      redirect_to whatsapp_fallback_message("Event registration is closed") and return
    end

    whatsapp_number = ENV["TWILIO_WHATSAPP_FROM"]
                    .gsub("whatsapp:", "")
                    .delete("+")
    message = "Hi, I would like to register for #{event.name}. EVENT_ID:#{event.id}"

    whatsapp_url = "https://wa.me/#{whatsapp_number}?text=#{message}"

    redirect_to whatsapp_url, allow_other_host: true
  end

  def handle_event_access(event)
    return "invalid" if event.nil?
    return "closed" unless event.active?
    "valid"
  end
end
