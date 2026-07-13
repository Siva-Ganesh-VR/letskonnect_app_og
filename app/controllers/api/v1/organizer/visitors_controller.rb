module Api
  module V1
    module Organizer
      class VisitorsController < ApplicationController
        before_action :authenticate_organizer!
        # set event when event_id is provided (index may be called with or without)
        before_action :set_event, if: -> { params[:event_id].present? }

        def index
          if params[:event_id].present?
            visitors = @event.visitors.verified
          else
            # collect visitors across all events owned by this organizer
            event_ids = @current_organizer.events.pluck(:id)
            visitors = ::Visitor.where(event_id: event_ids).verified
          end
          visitors = visitors.where("full_name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
          visitors = visitors.where(business_category: params[:category]) if params[:category].present?
          visitors = visitors.where(profession: params[:profession]) if params[:profession].present?
          visitors = visitors.order(created_at: :desc)

          per_page = params[:per_page].to_i
          per_page = 10 if per_page <= 0
          per_page = [per_page, 100].min
          pagy, paginated = pagy(visitors, items: per_page)

          json_success(
            paginated.map { |v| visitor_data(v) },
            meta: { total: pagy.count, page: pagy.page, pages: pagy.pages }
          )
        end

        def show
          visitor = @event.visitors.find(params[:id])
          json_success(visitor_data(visitor).merge(
            leads: visitor.leads.includes(:stall_owner).map { |l|
              { stall: l.stall_owner.company_name, temperature: l.temperature, scanned_at: l.scanned_at }
            }
          ))
        end

        def export
          job = ExportJob.create!(
            exportable:        @event,
            export_type:       params[:format] == "pdf" ? "visitors_pdf" : "visitors_excel",
            requested_by_type: "EventOrganizer",
            requested_by_id:   @current_organizer.id,
            expires_at:        24.hours.from_now
          )
          ExportVisitorsJob.perform_later(job.id)
          json_success({ job_id: job.id, message: "Export started" })
        end

        def export_status
          job = ExportJob.find(params[:job_id])
          json_success({ status: job.status, file_url: job.file_url })
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

        def set_event
          @event = @current_organizer.events.find(params[:event_id])
        end

        def visitor_data(v)
          { id: v.id, visitor_id_code: v.visitor_id_code, full_name: v.full_name,
            mobile_number: v.formatted_mobile_number, email: v.email, profession: v.profession,
            business_name: v.business_name, business_category: v.business_category,
            location: v.location, designation: v.designation,
            stalls_visited: v.leads.count, registered_at: v.created_at.iso8601,
            email: v.email, active: v.active, looking_for: v.looking_for,
            decision_maker: v.decision_maker, created_at: v.created_at, reg_type: v.reg_type,
            mobile_verified: v.mobile_verified,
            event: {
              id: v.event&.id,
              name: v.event&.name,
              code: v.event&.event_code
            }, }
        end
      end
    end
  end
end
