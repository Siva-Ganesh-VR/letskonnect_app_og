module Api
  module V1
    module SuperAdmin
      class VisitorsController < ApplicationController
        before_action :authenticate_super_admin!

        def index
          visitors = Visitor.where(mobile_verified: true).includes(:event).order(created_at: :desc)
          visitors = visitors.where(event_id: params[:event_id]) if params[:event_id].present?
          visitors = visitors.where("full_name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
          pagy, paged = pagy(visitors, items: 10)
          json_success(paged.map { |v| visitor_resp(v) }, meta: { total: pagy.count, pages: pagy.pages })
        end

        def show
          v = Visitor.find(params[:id])
          json_success(visitor_resp(v))
        end

        def destroy
          v = Visitor.find(params[:id])
          v.update!(active: false)
          json_success({ message: "Visitor deactivated" })
        end

        private
        def visitor_resp(v)
          { id: v.id, visitor_id_code: v.visitor_id_code, full_name: v.full_name.titleize,
            mobile_number: v.mobile_number, business_name: v&.business_name&.titleize,
            business_category: v.business_category, location: v.location, profession: v.profession, designation: v.designation, email: v.email, active: v.active, looking_for: v.looking_for, decision_maker: v.decision_maker, created_at: v.created_at, stalls_visited: v.leads.count,
            event_name: (v&.event&.name)&.titleize || "", registered_at: v.created_at }
        end
      end
    end
  end
end
