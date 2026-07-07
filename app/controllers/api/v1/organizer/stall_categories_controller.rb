module Api
  module V1
    module Organizer
      class StallCategoriesController < ApplicationController
        before_action :authenticate_organizer!

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
      end
    end
  end
end
