class VisitorPassesController < ActionController::Base
  layout false

  def show
    @visitor = Visitor.includes(:event).find_by(qr_token: params[:qr_token])
    if @visitor.nil? || !@visitor.mobile_verified?
      render plain: "Invalid QR code", status: :not_found and return
    end
    render :show
  end
end
