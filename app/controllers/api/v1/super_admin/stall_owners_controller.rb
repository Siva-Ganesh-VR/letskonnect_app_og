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
          @stall.update!(params.require(:stall_owner).permit(:name, :company_name, :stall_number, :stall_category, :active))
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

        private
        def set_stall
          @stall = ::StallOwner.find(params[:id])
        end

        def stall_resp(s)
          { id: s.id, name: s.name, email: s.email, mobile_number: s.mobile_number,
            company_name: s.company_name, stall_number: s.stall_number,
            stall_category: s.stall_category, active: s.active,
            total_leads_count: s.total_leads_count,
            event: { id: s.event.id, name: s.event.name } }
        end
      end
    end
  end
end
