module Api
  module V1
    module SuperAdmin
      class StallSizesController < ApplicationController
        before_action :authenticate_super_admin!

        def index
          json_success(StallSize.active.order(:name).select(:id, :name))
        end

        def create
          width = params[:width].to_s.strip
          height = params[:height].to_s.strip
          name = params[:name].to_s.strip
          name = "#{width}x#{height}" if name.blank? && width.present? && height.present?

          record = StallSize.new(name: name)
          if record.save
            json_success(record, status: :created)
          else
            json_error("Could not create stall size", errors: record.errors.full_messages)
          end
        end

        def update
          record = StallSize.find(params[:id])
          if record.update(name: params[:name].to_s.strip)
            json_success(record)
          else
            json_error("Could not update stall size", errors: record.errors.full_messages)
          end
        end

        def destroy
          record = StallSize.find(params[:id])
          record.update!(active: false)
          json_success({ message: "Deleted" })
        end
      end
    end
  end
end
