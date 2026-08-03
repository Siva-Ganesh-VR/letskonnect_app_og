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

    @template = if @event.template_id.present?
                  Template.find_by(
                    id: @event.template_id,
                    template_type: "question",
                    active: true
                  )
                else
                  Template.find_by(
                    template_type: "question",
                    is_default: true,
                    active: true
                  )
                end

    @questions = @template&.template_questions || []

    render :show
  end

end