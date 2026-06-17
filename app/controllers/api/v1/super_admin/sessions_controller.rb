module Api
  module V1
    module SuperAdmin
      class SessionsController < ApplicationController
        # POST /api/v1/super_admin/sign_in
        def create
          admin = ::SuperAdmin.find_by(email: params[:email]&.strip&.downcase)
          unless admin&.authenticate(params[:password])
            return json_error("Invalid email or password", status: :unauthorized)
          end
          json_success({ token: admin.issue_token, admin: { id: admin.id, name: admin.name, email: admin.email } })
        end

        # DELETE /api/v1/super_admin/sign_out
        def destroy
          authenticate_super_admin!
          return if performed?
          json_success({ message: "Signed out" })
        end
      end
    end
  end
end
