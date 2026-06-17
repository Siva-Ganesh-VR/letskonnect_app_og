module Api
  module V1
    module StallOwner
      class LeadsController < ApplicationController
        before_action :authenticate_stall_owner!
        before_action :set_lead, only: [:show, :update, :whatsapp, :call_log]

        # GET /api/v1/stall_owner/leads
        def index
          leads = @current_stall_owner.leads.includes(:visitor)

          leads = leads.where(temperature: params[:temperature]) if params[:temperature].present?
          leads = leads.where(status: params[:status])           if params[:status].present?
          leads = leads.where(follow_up_date: Date.parse(params[:follow_up_date])) if params[:follow_up_date].present?
          if params[:date].present?
            date = Date.parse(params[:date])
            leads = leads.where(scanned_at: date.beginning_of_day..date.end_of_day)
          end
          if params[:search].present?
            q = "%#{params[:search]}%"
            leads = leads.joins(:visitor).where(
              "visitors.full_name ILIKE ? OR visitors.mobile_number ILIKE ? OR visitors.business_name ILIKE ?", q, q, q
            )
          end

          leads = leads.order(scanned_at: :desc)
          pagy, paginated = pagy(leads, items: params[:per_page] || 20)

          json_success(
            paginated.map { |l| lead_with_visitor(l) },
            meta: {
              total:    pagy.count,
              page:     pagy.page,
              per_page: pagy.items,
              pages:    pagy.pages,
              summary:  Lead.summary_for_stall(@current_stall_owner.id)
            }
          )
        end

        # GET /api/v1/stall_owner/leads/summary
        def summary
          json_success(Lead.summary_for_stall(@current_stall_owner.id))
        end

        # GET /api/v1/stall_owner/leads/:id
        def show
          json_success(lead_with_visitor(@lead))
        end

        # PATCH /api/v1/stall_owner/leads/:id
        def update
          if @lead.update(lead_update_params)
            json_success(lead_with_visitor(@lead))
          else
            json_error("Update failed", errors: @lead.errors.full_messages)
          end
        end

        # POST /api/v1/stall_owner/leads/:id/whatsapp
        def whatsapp
          WhatsappService.send_followup(@lead.visitor, @current_stall_owner, params[:message])
          json_success({ message: "WhatsApp message sent" })
        end

        # POST /api/v1/stall_owner/leads/:id/call_log
        def call_log
          @lead.update!(remarks: "Called at #{Time.current.strftime('%d %b %Y %I:%M %p')}. #{params[:notes]}")
          json_success({ message: "Call logged" })
        end

        # POST /api/v1/stall_owner/leads/export
        def export
          job = ExportJob.create!(
            exportable:        @current_stall_owner,
            export_type:       "leads_excel",
            filters:           export_filter_params.to_h,
            requested_by_type: "StallOwner",
            requested_by_id:   @current_stall_owner.id,
            expires_at:        24.hours.from_now
          )
          ExportLeadsJob.perform_later(job.id)
          json_success({
            job_id:  job.id,
            message: "Export started. You will receive a WhatsApp message with the download link when ready."
          })
        end

        # GET /api/v1/stall_owner/leads/export/:job_id/status
        def export_status
          job = ExportJob.find_by!(id: params[:job_id], exportable: @current_stall_owner)
          json_success({ status: job.status, file_url: job.file_url, error: job.error_message })
        end

        private

        def set_lead
          @lead = @current_stall_owner.leads.includes(:visitor).find(params[:id])
        end

        def lead_update_params
          params.require(:lead).permit(
            :temperature, :interest_rating, :status,
            :notes, :requirements, :budget, :follow_up_date, :remarks
          )
        end

        def export_filter_params
          params.permit(:temperature, :status, :start_date, :end_date)
        end

        def lead_response(l)
          {
            id:             l.id,
            temperature:    l.temperature,
            status:         l.status,
            interest_rating: l.interest_rating,
            notes:          l.notes,
            requirements:   l.requirements,
            budget:         l.budget,
            follow_up_date: l.follow_up_date,
            remarks:        l.remarks,
            scanned_at:     l.scanned_at.iso8601,
            created_at:     l.created_at.iso8601
          }
        end

        def visitor_data(v)
          {
            id:                v.id,
            visitor_id_code:   v.visitor_id_code,
            full_name:         v.full_name,
            mobile_number:     v.mobile_number,
            email:             v.email,
            location:          v.location,
            profession:        v.profession,
            business_name:     v.business_name,
            business_category: v.business_category,
            designation:       v.designation
          }
        end

        def lead_with_visitor(l)
          lead_response(l).merge(visitor: visitor_data(l.visitor))
        end
      end
    end
  end
end
