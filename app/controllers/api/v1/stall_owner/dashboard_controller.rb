module Api
  module V1
    module StallOwner
      class DashboardController < ApplicationController
        before_action :authenticate_stall_owner!

        def show
          @stall_owner = ::StallOwner.find_by(
            event_id: params[:event_id],
            mobile_number: @current_stall_owner.mobile_number
          ) || @current_stall_owner

          events = Event
            .joins(:stall_owners)
            .where(stall_owners: { mobile_number: @current_stall_owner.mobile_number })
            .distinct
            .order(:name)

          json_success(
            {
              stall_owner: stall_owner_data,
              summary: dashboard_summary,
              recent_leads: recent_leads_data,
              follow_ups_today: follow_ups_today_data,
              events: events.map { |e| event_mini(e) }
            }
          )
        end

        private

        def stall_owner_data
          s = @stall_owner

          {
            id: s.id,
            name: s.name,
            company_name: s.company_name,
            stall_number: s.stall_number,
            stall_category: s.stall_category,
            total_leads_count: s.total_leads_count,
            event_id: s.event_id
          }
        end

        def dashboard_summary
          @stall_owner.dashboard_summary
        end

        def recent_leads_data
          @stall_owner.leads
                      .includes(:visitor)
                      .order(scanned_at: :desc)
                      .limit(5)
                      .map do |lead|
            {
              id: lead.id,
              visitor_name: lead.visitor.full_name,
              business_name: lead.visitor.business_name,
              temperature: lead.temperature,
              status: lead.status,
              scanned_at: lead.scanned_at.iso8601
            }
          end
        end

        def follow_ups_today_data
          @stall_owner.leads
                      .includes(:visitor)
                      .where(follow_up_date: Date.current)
                      .map do |lead|
            {
              id: lead.id,
              visitor_name: lead.visitor.full_name,
              mobile_number: lead.visitor.mobile_number,
              temperature: lead.temperature,
              notes: lead.notes
            }
          end
        end

        def event_mini(event)
          {
            id: event.id,
            name: event.name,
            venue: event.venue,
            start_date: event.start_date,
            end_date: event.end_date,
            status: event.status
          }
        end
      end
    end
  end
end