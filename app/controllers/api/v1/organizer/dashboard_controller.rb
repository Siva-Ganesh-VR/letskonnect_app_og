module Api
  module V1
    module Organizer
      class DashboardController < ApplicationController
        before_action :authenticate_organizer!

        def show
          events = @current_organizer.events.includes(:event_analytics)
          json_success({
            organizer: { name: @current_organizer.name, company: @current_organizer.company_name },
            events_summary: {
              total: events.count,
              active: events.where(status: "active").count,
              draft:  events.where(status: "draft").count
            },
            events: events.order(created_at: :desc).map { |e| event_card(e) }
          })
        end

        private

        def event_card(e)
          analytics = e.event_analytics
          {
            id: e.id, name: e.name, venue: e.venue, city: e.city,
            start_date: e.start_date, end_date: e.end_date, status: e.status,
            registered_count: e.registered_count,
            total_stalls: e.stall_owners.count,
            total_leads: analytics&.total_leads || 0,
            qr_image_url: e.qr_image_url,
            registration_qr_token: e.registration_qr_token,
          }
        end
      end
    end
  end
end
