module Api
  module V1
    module StallOwner
      class DashboardController < ApplicationController
        before_action :authenticate_stall_owner!

        def show
          json_success({
            stall_owner: stall_owner_data,
            summary:     @current_stall_owner.dashboard_summary,
            recent_leads: recent_leads_data,
            follow_ups_today: follow_ups_today_data
          })
        end

        private

        def stall_owner_data
          s = @current_stall_owner
          { id: s.id, name: s.name, company_name: s.company_name,
            stall_number: s.stall_number, stall_category: s.stall_category,
            total_leads_count: s.total_leads_count }
        end

        def recent_leads_data
          @current_stall_owner.leads.includes(:visitor)
            .order(scanned_at: :desc).limit(5).map do |l|
            { id: l.id, visitor_name: l.visitor.full_name,
              business_name: l.visitor.business_name,
              temperature: l.temperature, status: l.status,
              scanned_at: l.scanned_at.iso8601 }
          end
        end

        def follow_ups_today_data
          @current_stall_owner.leads.includes(:visitor)
            .where(follow_up_date: Date.today).map do |l|
            { id: l.id, visitor_name: l.visitor.full_name,
              mobile_number: l.visitor.mobile_number,
              temperature: l.temperature, notes: l.notes }
          end
        end
      end
    end
  end
end
