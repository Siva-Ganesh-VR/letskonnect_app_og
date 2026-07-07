module Api
  module V1
    module Organizer
      class StallSizesController < ApplicationController
        before_action :authenticate_organizer!

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
      end
    end
  end
end
