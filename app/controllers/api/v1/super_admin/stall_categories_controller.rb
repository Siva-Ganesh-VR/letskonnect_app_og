module Api
  module V1
    module SuperAdmin
      class StallCategoriesController < ApplicationController
        before_action :authenticate_super_admin!

        def index
          json_success(StallCategory.active.order(:name).select(:id, :name))
        end

        def create
          record = StallCategory.new(name: params[:name].to_s.strip)
          if record.save
            json_success(record, status: :created)
          else
            json_error("Could not create stall category", errors: record.errors.full_messages)
          end
        end

        def update
          record = StallCategory.find(params[:id])
          if record.update(name: params[:name].to_s.strip)
            json_success(record)
          else
            json_error("Could not update stall category", errors: record.errors.full_messages)
          end
        end

        def destroy
          record = StallCategory.find(params[:id])
          record.update!(active: false)
          json_success({ message: "Deleted" })
        end
      end
    end
  end
end
