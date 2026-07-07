module Api
  module V1
    module Organizer
      class DashboardController < ApplicationController
        before_action :authenticate_organizer!

        def show
          events = @current_organizer.events.includes(:event_analytics)
          sample_images = Dir.children(Rails.root.join("public", "images")).select { |f| f.start_with?("event_") }.map { |f| "/images/#{f}" }.shuffle
          image_count = sample_images.size

          json_success({
            organizer: { name: @current_organizer.name, company: @current_organizer.company_name },
            events_summary: {
              total: events.count,
              active: events.where(status: "active").count,
              draft:  events.where(status: "draft").count
            },
            events: events.order(created_at: :desc).map.with_index { |e, idx| event_card(e, image_count.positive? ? sample_images[idx % image_count] : nil) }
          })
        end

        private

        def event_card(e, banner_url = nil)
          analytics = e.event_analytics
          {
            id: e.id, name: e.name, venue: e.venue, city: e.city,
            start_date: e.start_date, end_date: e.end_date, status: e.status,
            registered_count: e.registered_count,
            total_stalls: e.stall_owners.count,
            total_leads: analytics&.total_leads || 0,
            banner_url: banner_url,
            registration_qr_token: e.registration_qr_token,
            settings: e.settings
          }
        end
      end
    end
  end
end
