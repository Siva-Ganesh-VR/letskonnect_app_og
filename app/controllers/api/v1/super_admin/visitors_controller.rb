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

        def visit_history
          visitor = Visitor.find(params[:id])

          logs = VisitorScanLog
                  .joins(:stall_owner, :event)
                  .where(visitor_id: visitor.id)

          logs = logs.where(event_id: params[:event_id]) if params[:event_id].present?

          if params[:search].present?
            q = "%#{params[:search].strip.downcase}%"

            logs = logs.where(
              "LOWER(events.name) LIKE :q
              OR LOWER(stall_owners.name) LIKE :q",
              q: q
            )
          end

          history = logs
                      .group(
                        "visitor_scan_logs.stall_owner_id",
                        "visitor_scan_logs.event_id",
                        "stall_owners.id",
                        "stall_owners.name",
                        "events.id",
                        "events.name"
                      )
                      .select(
                        "stall_owners.id AS stall_owner_id,
                        stall_owners.name AS stall_owner_name,
                        stall_owners.stall_number AS stall_number,
                        events.id AS event_id,
                        events.name AS event_name,
                        COUNT(visitor_scan_logs.id) AS visit_count,
                        MAX(visitor_scan_logs.scanned_at) AS last_visited_at"
                      )
                      .order("MAX(visitor_scan_logs.scanned_at) DESC")

          per_page = params[:per_page].to_i
          per_page = 10 if per_page <= 0
          per_page = [per_page, 100].min

          pagy, paginated = pagy(history, items: per_page)

          json_success(
            paginated.map do |visit|
              {
                stall_owner_id: visit.stall_owner_id,
                stall_owner_name: visit.stall_owner_name,
                stall_number: visit.stall_number,
                event_id: visit.event_id,
                event_name: visit.event_name,
                visit_count: visit.visit_count.to_i,
                last_visited_at: visit.last_visited_at
              }
            end,
            meta: {
              total: pagy.count,
              page: pagy.page,
              pages: pagy.pages,
              total_visits: logs.count
            }
          )
        end

        private
        def visitor_resp(v)
          lead = v.leads.find_by(visitor_id: v.id)
          { id: v.id, visitor_id_code: v.visitor_id_code, full_name: v.full_name.titleize,
            mobile_number: v.formatted_mobile_number, business_name: v&.business_name&.titleize,
            business_category: v.business_category, location: v.location, profession: v.profession, designation: v.designation, email: v.email, active: v.active, looking_for: v.looking_for, decision_maker: v.decision_maker, created_at: v.created_at, reg_type: v.reg_type, stalls_visited: v.leads.count, mobile_verified: v.mobile_verified,
            event_name: (v&.event&.name)&.titleize || "", registered_at: v.created_at,
            is_favorite: lead&.is_favorite || false
          }
        end
      end
    end
  end
end
