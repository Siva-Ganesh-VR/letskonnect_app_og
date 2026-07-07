module Api
  module V1
    module Organizer
      class StallTypesController < ApplicationController
        before_action :authenticate_organizer!

        def index
          json_success(StallType.active.order(:name).select(:id, :name))
        end

        def create
          record = StallType.new(name: params[:name].to_s.strip)
          if record.save
            json_success(record, status: :created)
          else
            json_error("Could not create stall type", errors: record.errors.full_messages)
          end
        end
      end
    end
  end
end
