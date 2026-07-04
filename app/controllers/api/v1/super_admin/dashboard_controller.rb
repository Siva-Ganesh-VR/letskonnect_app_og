module Api
  module V1
    module SuperAdmin
      class DashboardController < ApplicationController
        before_action :authenticate_super_admin!

        def show
          json_success({
            platform: {
              total_events:      Event.count,
              active_events:     Event.active_events.count,
              total_organizers:  EventOrganizer.count,
              active_organizers: EventOrganizer.active.count,
              total_visitors:    Visitor.verified.count,
              total_leads:       Lead.count,
              total_stalls:      ::StallOwner.count
            },

            recent_events: Event
              .order(created_at: :desc)
              .limit(5)
              .map do |e|
                {
                  id: e.id,
                  name: e.name,
                  status: e.status,
                  registered_count: e.registered_count,
                  start_date: e.start_date
                }
              end,

            recent_organizers: EventOrganizer
              .order(created_at: :desc)
              .limit(5)
              .map do |o|
                {
                  id: o.id,
                  name: o.name,
                  email: o.email,
                  active: o.active,
                  created_at: o.created_at
                }
              end
          })
        end
      end
    end
  end
end
