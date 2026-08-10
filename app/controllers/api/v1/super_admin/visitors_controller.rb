module Api
  module V1
    module SuperAdmin
      class VisitorsController < ApplicationController
        before_action :authenticate_super_admin!

        def index
          visitors = Visitor.where(mobile_verified: true).includes(:event).order(created_at: :desc)
          visitors = visitors.where(event_id: params[:event_id]) if params[:event_id].present?
          visitors = visitors.where("full_name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
          per_page = [[params[:per_page].to_i, 1].max, 500].min
          per_page = 10 if per_page == 0
          pagy, paged = pagy(visitors, items: per_page)
          json_success(paged.map { |v| visitor_resp(v) }, meta: { total: pagy.count, pages: pagy.pages, page: pagy.page })
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
              "LOWER(events.name) LIKE :q OR LOWER(stall_owners.name) LIKE :q",
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
                stall_owner_id:   visit.stall_owner_id,
                stall_owner_name: visit.stall_owner_name,
                stall_number:     visit.stall_number,
                event_id:         visit.event_id,
                event_name:       visit.event_name,
                visit_count:      visit.visit_count.to_i,
                last_visited_at:  visit.last_visited_at
              }
            end,
            meta: {
              total:        pagy.count,
              page:         pagy.page,
              pages:        pagy.pages,
              total_visits: logs.count
            }
          )
        end

        def export_visitors_excel
          visitors = Visitor.where(event_id: params[:event_id]).verified if params[:event_id].present?
          visitors = visitors.where("full_name ILIKE ?", "%#{params[:search]}%") if params[:search].present?

          package = Axlsx::Package.new
          workbook = package.workbook

          workbook.add_worksheet(name: "Visitors") do |sheet|
            sheet.add_row [
              "#", "Visitor ID", "Name", "Mobile", "Email",
              "Business Name", "Category", "Profession", "Location",
              "Designation", "Website", "Registered At"
            ]

            visitors.each_with_index do |v, i|
              sheet.add_row [
                i + 1,
                v.visitor_id_code,
                v.full_name,
                v.mobile_number,
                v.email,
                v.business_name,
                v.business_category,
                v.profession,
                v.location,
                v.designation,
                v.website,
                v.created_at.strftime("%d %b %Y %H:%M")
              ]
            end

            sheet.column_widths 4, 16, 25, 14, 28, 28, 20, 18, 15, 15, 28, 18
          end

          filename = "visitors_#{visitors.first.event.name.parameterize}_#{Date.current}.xlsx"

          send_data(
            package.to_stream.read,
            filename: filename,
            type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          )
        end

        private

        def visitor_resp(v)
          lead = v.leads.find_by(visitor_id: v.id)
          {
            id:                v.id,
            visitor_id_code:   v.visitor_id_code,
            full_name:         v.full_name&.titleize        || "",   # ← nil safe
            mobile_number:     v.formatted_mobile_number,
            business_name:     v.business_name&.titleize    || "",   # ← nil safe
            business_category: v.business_category          || "",
            location:          v.location                   || "",
            profession:        v.profession                 || "",
            designation:       v.designation                || "",
            email:             v.email                      || "",
            active:            v.active,
            looking_for:       v.looking_for                || "",
            decision_maker:    v.decision_maker,
            created_at:        v.created_at,
            reg_type:          v.reg_type                   || "",
            stalls_visited:    v.leads.count,
            mobile_verified:   v.mobile_verified,
            event_name:        v.event&.name&.titleize      || "",   # ← nil safe
            registered_at:     v.created_at,
            is_favorite:       lead&.is_favorite            || false,
            completed:         v.event&.completed?          || false, # ← nil safe
            qr_image_url:      v.qr_image_url
          }
        end
      end
    end
  end
end
