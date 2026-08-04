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
    when :invalid
      message = "Invalid event QR code"

      return event.whatsapp_enabled? ?
        redirect_to(whatsapp_fallback_message(message), allow_other_host: true) :
        render(plain: message, status: :not_found)

    when :draft
      message = "Event registration has not started yet."

      return event.whatsapp_enabled? ?
        redirect_to(whatsapp_fallback_message(message), allow_other_host: true) :
        render(plain: message, status: :forbidden)

    when :closed
      message = "Event registration is closed."

      return event.whatsapp_enabled? ?
        redirect_to(whatsapp_fallback_message(message), allow_other_host: true) :
        render(plain: message, status: :forbidden)
    end

    if event.whatsapp_enabled?
      whatsapp_number = ENV["TWILIO_WHATSAPP_FROM"]
                          .gsub("whatsapp:", "")
                          .delete("+")

      message = "Hi, I would like to register for #{event.name}. EVENT_CODE:#{event.event_code}"

      whatsapp_url = "https://wa.me/#{whatsapp_number}?text=#{CGI.escape(message)}"

      redirect_to whatsapp_url, allow_other_host: true
    else
      @event = event
      render :show
    end
  end

  def bni_show
    event = Event.find_by!(bni_registration_qr_token: params[:event_token])

    case handle_event_access(event)
    when :invalid
      message = "Invalid event BNI QR code"

      return event.whatsapp_enabled? ?
        redirect_to(whatsapp_fallback_message(message), allow_other_host: true) :
        render(plain: message, status: :not_found)

    when :draft
      message = "Event registration has not started yet."

      return event.whatsapp_enabled? ?
        redirect_to(whatsapp_fallback_message(message), allow_other_host: true) :
        render(plain: message, status: :forbidden)

    when :closed
      message = "Event registration is closed."

      return event.whatsapp_enabled? ?
        redirect_to(whatsapp_fallback_message(message), allow_other_host: true) :
        render(plain: message, status: :forbidden)
    end

    if event.whatsapp_enabled?
      whatsapp_number = ENV["TWILIO_WHATSAPP_FROM"]
                          .gsub("whatsapp:", "")
                          .delete("+")

      message = "Hi, I would like to register for #{event.name}. BNI_EVENT_CODE:#{event.event_code}"

      whatsapp_url = "https://wa.me/#{whatsapp_number}?text=#{CGI.escape(message)}"

      redirect_to whatsapp_url, allow_other_host: true
    else
      @event = event
      render :bni_show
    end
  end

  def handle_event_access(event)
    return :invalid if event.nil?
    return :draft if event.draft?
    return :closed if event.completed?

    :valid
  end

  private

  def whatsapp_fallback_message(message)
    whatsapp_number = ENV["TWILIO_WHATSAPP_FROM"].to_s.delete_prefix("whatsapp:+")
    text = CGI.escape(message)

    "https://wa.me/#{whatsapp_number}?text=#{text}"
  end
end
