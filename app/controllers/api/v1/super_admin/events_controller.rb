module Api
  module V1
    module SuperAdmin
      class EventsController < ApplicationController
        before_action :authenticate_super_admin!
        before_action :set_event, only: [:show, :update, :destroy, :analytics, :full_report, :generate_qr, :activate, :archive, :approve, :reject]

        def index
          events = Event.includes(:event_organizer, :event_analytics).order(created_at: :desc)
          if params[:status].present?
            events = events.where(status: params[:status])
          else
            events = events.where.not(status: "pending")
          end

          if params[:search].present?
            q = "%#{params[:search]}%"
            events = events.where("name ILIKE ? OR venue ILIKE ? OR city ILIKE ?", q, q, q)
          end

          pagy_obj, paginated = pagy(events, page: params[:page], items: params[:per_page] || 10)
          json_success(
            paginated.map { |e| event_detail(e) },
            meta: { total: pagy_obj.count, page: pagy_obj.page, per_page: pagy_obj.items, pages: pagy_obj.pages }
          )
        end

        def show
          json_success(event_full(  @event))
        end

        def create
          organizer = EventOrganizer.find(params[:event_organizer_id])
          event = organizer.events.create!(event_params)
          json_success(event_detail(event), status: :created)
        end

        def update
          Rails.logger.warn("event params: #{event_params}")
          @event.update!(event_params)
          json_success(event_detail(@event))
        end

        def destroy
          @event.update!(status: "archived")
          json_success({ message: "Event archived" })
        end

        def analytics
          a = @event.event_analytics
          json_success({
            overview: {
              total_visitors: @event.registered_count,
              total_leads:    a.total_leads,
              total_stalls:   @event.stall_owners.count,
              hot_leads:      a.hot_leads,
              warm_leads:     a.warm_leads,
              cold_leads:     a.cold_leads
            },
            visitors_by_category:  a.visitors_by_category,
            visitors_by_location:  a.visitors_by_location,
            stall_performance:     a.stall_performance,
            hourly_registrations:  a.hourly_registrations,
            top_stalls: @event.stall_owners.order(total_leads_count: :desc).limit(10).map { |s|
              { name: s.company_name, stall_number: s.stall_number, leads: s.total_leads_count }
            }
          })
        end

        def generate_qr
          QrGenerationJob.perform_later(@event.id, "event")
          json_success({ message: "QR regeneration queued" })
        end

        def activate
          @event.update!(status: "active")
          json_success({ message: "Event activated", status: "active" })
        end

        def archive
          @event.update!(status: "archived")
          json_success({ message: "Event archived", status: "archived" })
        end

        def approve
          target_status = params[:status].presence || "active"
          unless %w[draft active].include?(target_status)
            return json_error("Invalid approval status. Must be draft or active.")
          end
          @event.update!(status: target_status)
          json_success({ message: "Event approved successfully as #{target_status}", status: target_status })
        end

        def reject
          @event.update!(status: "archived")
          json_success({ message: "Event rejected" })
        end

        private

        def set_event
          @event = Event.find(params[:id])
        end

        def event_params
          params.require(:event).permit(
            :name, :description, :venue, :city, :start_date, :end_date,
            :start_time, :end_time, :max_visitors, :status, :event_organizer_id, settings: {}
          )
        end

        def event_detail(e)
          { id: e.id, event_code: e.event_code, name: e.name.titleize, venue: e.venue.titleize, city: e.city.titleize,
            start_date: e.start_date, end_date: e.end_date, status: e.status,
            registered_count: e.registered_count, qr_image_url: e.qr_image_url,
            organizer: { id: e.event_organizer.id, name: e.event_organizer.name },
            total_leads: e.event_analytics&.total_leads || 0, created_at: e.created_at,
            registration_qr_token: e.registration_qr_token, event_organizer_id: e.event_organizer_id, max_visitors: e.max_visitors, description: e.description,
            settings: e.settings }
        end

        def event_full(e)
          event_detail(e).merge(
            stall_count: e.stall_owners.count,
            description: e.description,
            settings: e.settings,
            registration_qr_token: e.registration_qr_token,
            registration_url: e.registration_url,
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
      end
    end
  end
end
