# app/controllers/api/v1/organizer/lucky_draw_results_controller.rb
module Api
  module V1
    module Organizer
      class LuckyDrawResultsController < ApplicationController
        before_action :authenticate_organizer!
        before_action :set_event

        def index
          results = LuckyDrawResult
            .for_event(@event.id)
            .includes(:visitor, :drawn_by)
          json_success(results.map { |r| result_data(r) })
        end

        def create
          if @event.end_date.present? && @event.end_date < Date.current
            return json_error("Lucky draw is closed — this event has ended.")
          end

          visitors = @event.visitors.verified
          return json_error("No registered visitors for this event yet.") if visitors.empty?

          already_won_ids = LuckyDrawResult.where(event_id: @event.id).pluck(:visitor_id)

          # Check if admin pre-selected a winner from secret panel
          winner = if @event.forced_winner_visitor_id.present?
            forced = visitors.find_by(id: @event.forced_winner_visitor_id)
            # Clear after use so next spin is random
            @event.update_column(:forced_winner_visitor_id, nil)
            forced
          end

          # Fall back to random if no forced winner set
          unless winner
            pool = visitors.where.not(id: already_won_ids)
            pool = visitors if pool.empty?
            winner = pool.order("RANDOM()").first
          end

          return json_error("Could not pick a winner.") unless winner

          result = LuckyDrawResult.create!(
            event:    @event,
            visitor:  winner,
            drawn_by: @current_organizer
          )
          json_success(result_data(result))
        end

        def destroy_all
          LuckyDrawResult.where(event_id: @event.id).delete_all
          @event.update_column(:forced_winner_visitor_id, nil)
          json_success({ message: "Lucky draw results cleared." })
        end

        def destroy
          result = LuckyDrawResult.find_by(id: params[:id], event_id: @event.id)
          return json_error("Result not found", status: :not_found) unless result
          result.destroy!
          json_success({ message: "Winner removed." })
        end

        private

        def set_event
          @event = @current_organizer.events.find(params[:event_id])
        rescue ActiveRecord::RecordNotFound
          json_error("Event not found", status: :not_found)
        end

        def result_data(r)
          v = r.visitor
          drawn_by_name = case r.drawn_by_type
            when "EventOrganizer" then "Organizer: #{r.drawn_by&.name}"
            when "SuperAdmin"     then "Admin: #{r.drawn_by&.name}"
            else "—"
          end
          {
            id:            r.id,
            round:         r.round,
            drawn_at:      r.created_at.iso8601,
            drawn_by:      drawn_by_name,
            drawn_by_type: r.drawn_by_type,
            visitor: {
              id:                v.id,
              visitor_id_code:   v.visitor_id_code,
              full_name:         v.full_name,
              mobile_number:     v.formatted_mobile_number,
              business_name:     v.business_name,
              business_category: v.business_category,
              location:          v.location,
              designation:       v.designation
            }
          }
        end
      end
    end
  end
end
