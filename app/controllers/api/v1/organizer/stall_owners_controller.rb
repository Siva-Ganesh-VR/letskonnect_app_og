module Api
  module V1
    module Organizer
      class StallOwnersController < ApplicationController
        before_action :authenticate_organizer!
        before_action :set_event

        def index
          stalls = @event.stall_owners.order(:stall_number)
          json_success(stalls.map { |s| stall_response(s) })
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

            stall = @event.stall_owners.build(
              name: row["name"]&.strip,
              mobile_number: row["mobile_number"]&.strip,
              company_name: row["company_name"]&.strip,
              stall_number: row["stall_number"]&.strip,
              stall_category: row["stall_category"]&.strip,
              email: row["email"]&.strip,
              password: generated_password,
              password_confirmation: generated_password
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
            stall = @event.stall_owners.build(
              row.permit(
                :name,
                :mobile_number,
                :company_name,
                :stall_number,
                :stall_category,
                :email,
                :website
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

        def set_event
          @event = @current_organizer.events.find(params[:event_id])
        end

        def stall_params
          params.require(:stall_owner).permit(
            :name, :email, :mobile_number, :company_name,
            :stall_number, :stall_category, :description, :website
          )
        end

        def stall_update_params
          params.require(:stall_owner).permit(
            :name, :email, :company_name, :stall_number,
            :stall_category, :description, :website, :active
          )
        end

        def stall_response(s)
          { id: s.id, name: s.name, email: s.email, mobile_number: s.mobile_number,
            company_name: s.company_name, stall_number: s.stall_number,
            stall_category: s.stall_category, active: s.active,
            total_leads_count: s.total_leads_count, created_at: s.created_at, website: s.website, pass_code: s.pass_code }
        end
      end
    end
  end
end
