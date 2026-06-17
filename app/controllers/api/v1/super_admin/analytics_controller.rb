module Api
  module V1
    module SuperAdmin
      class AnalyticsController < ApplicationController
        before_action :authenticate_super_admin!

        def platform
          json_success({
            platform: {
              total_events:      Event.count,
              active_events:     Event.active_events.count,
              total_organizers:  EventOrganizer.count,
              active_organizers: EventOrganizer.active.count,
              total_visitors:    Visitor.where(mobile_verified: true).count,
              total_leads:       Lead.count,
              total_stalls:      StallOwner&.count,
              hot_leads:         Lead.where(temperature: "hot").count,
              converted_leads:   Lead.where(status: "converted").count
            }
          })
        end
      end
    end
  end
end
