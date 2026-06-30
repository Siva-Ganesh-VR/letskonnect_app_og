module Api
  module V1
    module SuperAdmin
      class StallOwnersController < ApplicationController
        before_action :authenticate_super_admin!
        before_action :set_stall, only: [:show, :update, :destroy, :activate, :deactivate]

        def index
          stalls = ::StallOwner.includes(:event).order(created_at: :desc)
          stalls = stalls.where(event_id: params[:event_id]) if params[:event_id].present?
          json_success(stalls.map { |s| stall_resp(s) })
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
          require "csv"
          file = params[:file]
          return json_error("CSV file is required") unless file

          created, errors = [], []
          CSV.foreach(
            file.path,
            headers: true,
            encoding: "bom|utf-8"
          ).with_index(2) do |row, line_no|

            generated_password = SecureRandom.alphanumeric(8)

            stall = ::StallOwner.new(
              name: row["name"]&.strip,
              mobile_number: row["mobile_number"]&.strip,
              company_name: row["company_name"]&.strip,
              stall_number: row["stall_number"]&.strip,
              stall_category: row["stall_category"]&.strip,
              email: row["email"]&.strip,
              password: generated_password,
              password_confirmation: generated_password,
              event_id: params[:event_id]
            )

            stall.event_organizer = @current_organizer
            stall.pass_code = rand(100000..999999).to_s

            if stall.save
              created << stall.id
              # WhatsappNotificationJob.perform_later(stall.id, "stall_credentials", stall.password)
            else
              errors << { line: line_no, errors: stall.errors.full_messages }
            end
          end

          json_success({ created_count: created.size, failed_count: errors.size, errors: errors })
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

            stall.event_organizer = @current_organizer
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
            stall_category: s.stall_category, active: s.active, website: s.website, pass_code: s.pass_code,
            total_leads_count: s.total_leads_count,
            event: { id: s.event.id, name: s.event.name } }
        end
      end
    end
  end
end
