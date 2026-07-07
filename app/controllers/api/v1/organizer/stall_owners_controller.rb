module Api
  module V1
    module Organizer
      class StallOwnersController < ApplicationController
        before_action :authenticate_organizer!
        # set event when event_id is provided (index may be called with or without)
        before_action :set_event, if: -> { params[:event_id].present? }

        def index
          if params[:event_id].present?
            stalls = @event.stall_owners.order(:stall_number)
          else
            event_ids = @current_organizer.events.pluck(:id)
            stalls = ::StallOwner.where(event_id: event_ids).order(:stall_number)
          end

          if params[:search].present?
            q = "%#{params[:search]}%"
            stalls = stalls.where(
              "name ILIKE ? OR company_name ILIKE ? OR mobile_number ILIKE ?",
              q, q, q
            )
          end

          if params[:category].present? && params[:category] != "all"
            stalls = stalls.where(stall_category: params[:category])
          end

          per_page = params[:per_page].to_i
          per_page = 10 if per_page <= 0
          per_page = [per_page, 100].min
          pagy, paginated = pagy(stalls, items: per_page)

          json_success(
            paginated.map { |s| stall_response(s) },
            meta: {
              total: pagy.count,
              page: pagy.page,
              per_page: pagy.items,
              pages: pagy.pages
            }
          )
        end

        def show
          stall = @event.stall_owners.find(params[:id])
          json_success(stall_response(stall).merge(summary: stall.dashboard_summary))
        end

        def create
          stall = @event.stall_owners.build(stall_params)
          stall.event_organizer = @current_organizer
          # Auto-generate password
          password = SecureRandom.alphanumeric(10)
          stall.password = stall.password_confirmation = password

          if stall.save
            WhatsappNotificationJob.perform_later(stall.id, "stall_credentials", password)
            json_success(stall_response(stall), status: :created)
          else
            json_error("Could not create stall", errors: stall.errors.full_messages)
          end
        end

        def update
          stall = @event.stall_owners.find(params[:id])
          if stall.update(stall_update_params)
            json_success(stall_response(stall))
          else
            json_error("Could not update stall", errors: stall.errors.full_messages)
          end
        end

        def destroy
          stall = @event.stall_owners.find(params[:id])
          stall.update!(active: false)
          json_success({ message: "Stall deactivated" })
        end

        def send_credentials
          stall = @event.stall_owners.find(params[:id])
          new_password = SecureRandom.alphanumeric(10)
          stall.update!(password: new_password)
          WhatsappNotificationJob.perform_later(stall.id, "stall_credentials", new_password)
          json_success({ message: "Credentials sent via WhatsApp" })
        end

        def toggle_active
          stall = @event.stall_owners.find(params[:id])
          stall.update!(active: !stall.active)
          json_success({ active: stall.active, message: "Stall #{stall.active? ? "activated" : "deactivated"}" })
        end

        # POST /api/v1/organizer/events/:event_id/stall_owners/bulk_upload
        def bulk_upload
          file = params[:file]

          return json_error("CSV file is required") unless file

          temp_file_path = Rails.root.join(
            "tmp",
            "imports",
            "#{SecureRandom.uuid}_#{file.original_filename}"
          )

          FileUtils.mkdir_p(File.dirname(temp_file_path))
          File.binwrite(temp_file_path, file.read)

          StallOwnerImportJob.perform_later(
            temp_file_path.to_s,
            params[:event_id]
          )

          json_success({
            message: "Stall owner import has been initiated."
          })
        end

        def bulk_create
          created = []
          errors = []

          mobile_numbers = params[:stall_owners].map { |row| row[:mobile_number] }

          existing_stall_owners = ::StallOwner
            .where(mobile_number: mobile_numbers)
            .index_by(&:mobile_number)

          params[:stall_owners].each_with_index do |row, index|
            generated_password = SecureRandom.alphanumeric(8)

            stall = @event.stall_owners.build(
              row.permit(
                :name,
                :mobile_number,
                :company_name,
                :stall_number,
                :stall_category,
                :stall_type,
                :stall_size,
                :email,
                :website
              )
            )

            # Explicitly set associations
            stall.event = @event
            stall.event_organizer = @current_organizer

            stall.pass_code = rand(100000..999999).to_s
            stall.password = generated_password
            stall.password_confirmation = generated_password

            if (existing = existing_stall_owners[stall.mobile_number])
              stall.pass_code = existing.pass_code
            end

            if stall.save
              created << stall.id
            else
              Rails.logger.error(
                "STALL CREATE FAILED: #{stall.errors.full_messages.inspect}"
              )

              errors << {
                row: index + 1,
                errors: stall.errors.full_messages
              }
            end
          end

          json_success(
            {
              created_count: created.count,
              failed_count: errors.count,
              errors: errors
            },
            status: :ok
          )
        end

        private

        def set_event
          @event = @current_organizer.events.find(params[:event_id])
        end

        def stall_params
          params.require(:stall_owner).permit(
            :name, :email, :mobile_number, :company_name,
            :stall_number, :stall_category, :stall_type, :stall_size, :description, :website
          )
        end

        def stall_update_params
          params.require(:stall_owner).permit(
            :name, :email, :company_name, :stall_number,
            :stall_category, :stall_type, :stall_size, :description, :website, :active
          )
        end

        def stall_response(s)
          {
            id: s.id,

            # Codes
            stall_code: s.stall_code,
            event_code: s.event&.event_code,
            org_code: s.event_organizer&.org_code,

            # Details
            name: s.name,
            email: s.email,
            mobile_number: s.mobile_number,
            company_name: s.company_name,
            stall_number: s.stall_number,
            stall_category: s.stall_category,
            stall_type: s.stall_type,
            stall_size: s.stall_size,

            # Event & Organizer info
            event: {
              id: s.event&.id,
              name: s.event&.name,
              code: s.event&.event_code
            },

            organizer: {
              id: s.event_organizer&.id,
              name: s.event_organizer&.company_name,
              code: s.event_organizer&.org_code
            },

            # Status
            active: s.active,
            total_leads_count: s.total_leads_count,

            # Credentials
            pass_code: s.pass_code,

            # Misc
            website: s.website,
            created_at: s.created_at
          }
        end
      end
    end
  end
end
