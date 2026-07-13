module Api
  module V1
    module Organizer
      class EventsController < ApplicationController
        before_action :authenticate_organizer!
        before_action :set_event, only: [:show, :update, :analytics, :qr_code, :activate, :archive, :request_activation]

        def index
          events = @current_organizer.events.order(created_at: :desc)
          json_success(events.map { |e| event_summary(e) })
        end

        def show
          json_success(event_detail(@event))
        end

        def create
          event = @current_organizer.events.build(event_params)
          if event.save
            json_success(event_summary(event), status: :created)
          else
            json_error("Could not create event", errors: event.errors.full_messages)
          end
        end

        def update
          if @event.update(event_params)
            json_success(event_summary(@event))
          else
            json_error("Could not update event", errors: @event.errors.full_messages)
          end
        end

        def analytics
          a = @event.event_analytics
          json_success({
            overview: {
              total_visitors:  @event.registered_count,
              total_stalls:    @event.stall_owners.count,
              total_leads:     a.total_leads,
              hot_leads:       a.hot_leads,
              warm_leads:      a.warm_leads,
              cold_leads:      a.cold_leads
            },
            visitors_by_category:   a.visitors_by_category,
            visitors_by_location:   a.visitors_by_location,
            visitors_by_profession: a.visitors_by_profession,
            hourly_registrations:   a.hourly_registrations,
            top_stalls: top_stalls
          })
        end

        def qr_code
          json_success({
            qr_image_url:       @event.qr_image_url,
            registration_url:   @event.registration_url,
            qr_token:           @event.registration_qr_token
          })
        end

        def activate
          @event.update!(status: "active")
          json_success({ message: "Event activated", status: "active" })
        end

        def request_activation
          settings = @event.settings || {}
          if settings["activation_requested"]
            return json_error("Activation already requested", status: :unprocessable_entity)
          end
          
          settings["activation_requested"] = true
          settings["activation_requested_at"] = Time.current
          @event.update!(settings: settings)
          json_success({ message: "Activation requested", settings: settings })
        end

        def archive
          @event.update!(status: "archived")
          json_success({ message: "Event archived", status: "archived" })
        end

        def visitor_analytics
          event = @current_organizer.events.find(params[:id])
          leads = event.leads
          total_unique_visitors = leads.count

          json_success({
            total_unique_visitors: total_unique_visitors,
            visitors_by_day: day_wise_visitors(event)
          })
        end

        private

        def set_event
          @event = @current_organizer.events.find(params[:id])
        end

        def event_params
          params.require(:event).permit(
            :name, :description, :venue, :city,
            :start_date, :end_date, :start_time, :end_time,
            :max_visitors, :status, settings: {}
          )
        end

        def event_summary(e)
          {
            id: e.id,

            event_code: e.event_code,      # ADD

            name: e.name,
            venue: e.venue,
            city: e.city,
            start_date: e.start_date,
            end_date: e.end_date,
            status: e.status,
            slug: e.slug,
            registration_qr_token: e.registration_qr_token,
            qr_image_url: e.qr_image_url,
            registered_count: e.registered_count,
            max_visitors: e.max_visitors,
            created_at: e.created_at,
            description: e.description,
            settings: e.settings,

            organizer: {
              id: e.event_organizer.id,
              org_code: e.event_organizer.org_code,   # ADD
              name: e.event_organizer.name
            }
          }
        end

        def event_detail(e)
          event_summary(e).merge(
            stall_owners: e.stall_owners.active.map do |s|
              {
                id: s.id,
                stall_code: s.stall_code,
                name: s.name,
                company_name: s.company_name,
                stall_number: s.stall_number,
                category: s.stall_category,
                total_leads: s.total_leads_count,
                active: s.active
              }
            end
          )
        end

        def top_stalls
          @event.stall_owners
                .order(total_leads_count: :desc)
                .limit(10)
                .map do |s|
            {
              id: s.id,
              stall_code: s.stall_code,   # ADD
              company_name: s.company_name,
              stall_number: s.stall_number,
              leads: s.total_leads_count
            }
          end
        end

        def day_wise_visitors(event)
          day_counts = event.leads
                            .group("DATE(scanned_at)")
                            .count

          hour_counts = event.leads
                            .group(
                              "DATE(scanned_at)",
                              "EXTRACT(HOUR FROM scanned_at)"
                            )
                            .count

          (event.start_date.to_date..event.end_date.to_date).each_with_index.map do |date, index|
            {
              day: "Day #{index + 1}",
              date: date,
              visitors: day_counts[date] || 0,
              hours: (0..23).map do |hour|
                {
                  time: format("%02d:00 - %02d:00", hour, (hour + 1) % 24),
                  visitors: hour_counts[[date, hour.to_f]] || 0
                }
              end
            }
          end
        end
      end
    end
  end
end
