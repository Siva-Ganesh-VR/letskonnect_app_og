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

          pagy, paginated = pagy(
            stalls,
            items: params[:per_page] || 10
          )

          json_success(
            paginated.map { |s| stall_resp(s) },
            meta: {
              total: pagy.count,
              page: pagy.page,
              per_page: pagy.items,
              pages: pagy.pages
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

            if stall.save
              created << stall.id
            else
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
        def set_stall
          @stall = ::StallOwner.find(params[:id])
        end

        def stall_resp(s)
          { id: s.id, name: s.name, email: s.email, mobile_number: s.mobile_number,
            company_name: s.company_name, stall_number: s.stall_number,
            stall_category: s.stall_category, active: s.active, website: s.website, pass_code: s.pass_code, description: s.description,
            total_leads_count: s.total_leads_count,
            event: { id: s.event.id, name: s.event.name } }
        end
      end
    end
  end
end
