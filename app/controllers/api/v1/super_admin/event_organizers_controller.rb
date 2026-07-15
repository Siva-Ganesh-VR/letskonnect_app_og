module Api
  module V1
    module SuperAdmin
      class EventOrganizersController < ApplicationController
        before_action :authenticate_super_admin!
        before_action :set_organizer, only: [:show, :update, :activate, :deactivate, :reset_password]

        def index
          organizers = EventOrganizer.order(created_at: :desc)

          if params[:search].present?
            q = "%#{params[:search]}%"
            organizers = organizers.where(
              "name ILIKE ? OR mobile_number ILIKE ? OR company_name ILIKE ?",
              q, q, q
            )
          end

          pagy_obj, records = pagy(organizers, page: params[:page], items: params[:per_page] || 10)

          json_success(
            records.map { |o| organizer_response(o) },
            meta: {
              total: pagy_obj.count,
              page: pagy_obj.page,
              per_page: pagy_obj.items,
              pages: pagy_obj.pages
            }
          )
        end

        def show
          json_success(organizer_response(@organizer).merge(
            events_count: @organizer.events.count,
            active_events: @organizer.events.active_events.count
          ))
        end

        def create
          password = params[:password] || SecureRandom.alphanumeric(12)
          organizer = @current_super_admin.event_organizers.build(organizer_params)
          organizer.password = organizer.password_confirmation = password

          if organizer.save
            # TODO: send welcome WhatsApp/email with credentials
            json_success(organizer_response(organizer), status: :created)
          else
            Rails.logger.error organizer.errors.full_messages
            json_error("Could not create organizer", errors: organizer.errors.full_messages)
          end
        end

        def update
          if @organizer.update(organizer_update_params)
            json_success(organizer_response(@organizer))
          else
            json_error("Update failed", errors: @organizer.errors.full_messages)
          end
        end

        def activate
          @organizer.update!(active: true)
          json_success({ message: "Organizer activated" })
        end

        def deactivate
          @organizer.update!(active: false)
          json_success({ message: "Organizer deactivated" })
        end

        def reset_password
          new_password = SecureRandom.alphanumeric(12)
          @organizer.update!(password: new_password, password_confirmation: new_password)
          # Send via WhatsApp/email
          json_success({ message: "Password reset. New credentials sent to organizer." })
        end

        def events
          organizer = EventOrganizer.find(params[:id])

          events = organizer.events.order(start_date: :desc)

          if params[:search].present?
            q = "%#{params[:search]}%"
            events = events.where(
              "name ILIKE ? OR venue ILIKE ? OR city ILIKE ?",
              q, q, q
            )
          end

          pagy_obj, records = pagy(
            events,
            page: params[:page],
            items: params[:per_page] || 10
          )

          json_success(
            records.map { |e| event_response(e) },
            meta: {
              total: pagy_obj.count,
              page: pagy_obj.page,
              per_page: pagy_obj.items,
              pages: pagy_obj.pages
            }
          )
        end

        private

        def set_organizer
          @organizer = EventOrganizer.find(params[:id])
        end

        def organizer_params
          params.require(:event_organizer).permit(:name, :email, :mobile_number, :company_name)
        end

        def organizer_update_params
          params.require(:event_organizer).permit(:name, :company_name, :mobile_number, :logo_url)
        end

        def organizer_response(o)
          {
            id: o.id,
            org_code: o.org_code,   # ← add here
            name: o.name.titleize,
            email: o.email,
            mobile_number: o.formatted_mobile_number,
            company_name: o.company_name.titleize,
            active: o.active,
            created_at: o.created_at
          }
        end

        def event_response(event)
          {
            id: event.id,
            name: event.name,
            venue: event.venue,
            city: event.city,
            status: event.status,
            start_date: event.start_date,
            end_date: event.end_date,
            registered_count: event.visitors.count,
            qr_image_url: event.qr_image_url,
            registration_qr_token: event.registration_qr_token,
            max_visitors: event.max_visitors,
            completed: event.completed?
          }
        end
      end
    end
  end
end
