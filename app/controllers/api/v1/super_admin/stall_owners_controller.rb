module Api
  module V1
    module SuperAdmin
      class StallOwnersController < ApplicationController
        before_action :authenticate_super_admin!
        before_action :set_stall, only: [:show, :update, :destroy, :activate, :deactivate]

        def index
          stalls = ::StallOwner.includes(:event).order(created_at: :desc)
          stalls = stalls.where(event_id: params[:event_id]) if params[:event_id].present?

          if params[:search].present?
            q = "%#{params[:search]}%"
            stalls = stalls.where(
              "name ILIKE ? OR company_name ILIKE ? OR mobile_number ILIKE ?",
              q, q, q
            )
          end

          if params[:event_filter].present?
            stalls = stalls.where(event_id: params[:event_filter])
          end

          pagy_obj, paginated = pagy(
            stalls,
            page: params[:page],
            items: params[:per_page] || 10
          )

          json_success(
            paginated.map { |s| stall_resp(s) },
            meta: {
              total: pagy_obj.count,
              page: pagy_obj.page,
              per_page: pagy_obj.items,
              pages: pagy_obj.pages
            }
          )
        end

        def show
          json_success(stall_resp(@stall).merge(summary: @stall.dashboard_summary))
        end

        def update
          @stall.update!(params.require(:stall_owner).permit(:name, :company_name, :stall_number, :stall_category, :email, :website, :active))
          json_success(stall_resp(@stall))
        end

        def destroy
          @stall.update!(active: false)
          json_success({ message: "Deactivated" })
        end

        def activate
          @stall.update!(active: true)
          json_success({ message: "Stall activated" })
        end

        def deactivate
          @stall.update!(active: false)
          json_success({ message: "Stall deactivated" })
        end

        def bulk_upload
          Rails.logger.info("Bulk upload params: #{params.inspect}")
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
            stall = ::StallOwner.new(
              row.permit(
                :name,
                :mobile_number,
                :company_name,
                :stall_number,
                :stall_category,
                :email,
                :website,
                :event_id
              )
            )
            event = Event.find(row["event_id"])
            unless event
              errors << {
                row: index + 1,
                errors: "Event not found"
              }
              next
            end

            stall.event_organizer = event.event_organizer
            stall.pass_code = rand(100000..999999).to_s
            stall.password = stall.password_confirmation = generated_password

            if (existing = existing_stall_owners[stall.mobile_number])
              stall.pass_code = existing.pass_code
            end

            begin
              stall.save!
              created << stall.id
            rescue => e
              Rails.logger.error "ERROR: #{e.class}"
              Rails.logger.error e.message
              Rails.logger.error e.backtrace.first(20)

              errors << {
                row: index + 1,
                errors: "#{e.class}: #{e.message}"
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
        def set_stall
          @stall = ::StallOwner.find(params[:id])
        end

        def stall_resp(s)
          { id: s.id, stall_code: s.stall_code, name: s.name.titleize, email: s.email, mobile_number: s.mobile_number,
            company_name: s.company_name.titleize, stall_number: s.stall_number.upcase,
            stall_category: s.stall_category, active: s.active, website: s.website, pass_code: s.pass_code, description: s.description,
            total_leads_count: s.total_leads_count,
            event: { id: s.event.id, name: s.event.name.titleize, event_code: s.event.event_code } }
        end
      end
    end
  end
end
