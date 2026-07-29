class FeedbackController < ActionController::Base
  layout false

  def show
    @visitor = Visitor
      .includes(:event)
      .find_by(qr_token: params[:qr_token])

    unless @visitor&.mobile_verified?
      render plain: "Invalid or expired feedback link", status: :not_found
      return
    end

    @event = @visitor.event

    unless @event
      render plain: "Event not found", status: :not_found
      return
    end

    render :show
  end

  def create
    event = Event.find(params[:event_id])
    visitor = Visitor.find(params[:visitor_id])

    unless visitor.event_id == event.id
      render json: {
        success: false,
        error: "Visitor does not belong to this event"
      }, status: :unprocessable_entity
      return
    end

    feedback = Feedback.new(
      event: event,
      visitor: visitor,
      **feedback_params
    )

    if feedback.save
      render json: {
        success: true,
        message: "Feedback submitted successfully"
      }, status: :created
    else
      render json: {
        success: false,
        error: feedback.errors.full_messages.to_sentence
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: "Event or visitor not found"
    }, status: :not_found
  end

  private

  def feedback_params
    params.require(:feedback).permit(
      :overall_rating,
      :organization_rating,
      :venue_rating,
      :exhibitor_rating,
      :liked,
      :improvements,
      :recommend
    )
  end
end