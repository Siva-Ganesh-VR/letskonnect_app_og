module Api
  module V1
    module StallOwner
      class ProfileController < ApplicationController
        before_action :authenticate_stall_owner!

        def show
          s = @current_stall_owner
          json_success({ id: s.id, name: s.name, email: s.email, mobile_number: s.mobile_number,
            company_name: s.company_name, stall_number: s.stall_number, stall_category: s.stall_category,
            logo_url: s.logo_url, website: s.website, total_leads_count: s.total_leads_count })
        end

        def update
          @current_stall_owner.update!(params.require(:stall_owner).permit(:name, :email, :website, :description))
          json_success({ message: "Profile updated" })
        end
      end
    end
  end
end
