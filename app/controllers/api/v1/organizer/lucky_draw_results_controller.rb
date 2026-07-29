module Api
  module V1
    module Organizer
      class LuckyDrawResultsController < ApplicationController
        before_action :authenticate_organizer!
        before_action :set_event

        # GET /api/v1/organizer/events/:event_id/lucky_draw_results
        def index
          results = LuckyDrawResult
            .for_event(@event.id)
            .includes(:visitor, :drawn_by)
          json_success(results.map { |r| result_data(r) })
        end

        # POST /api/v1/organizer/events/:event_id/lucky_draw_results
        def create
          # Block spins AFTER the end date day is fully over.
          # Spins on the end date itself are allowed.
          if @event.end_date.present? && @event.end_date < Date.current
            return json_error("Lucky draw is closed — this event has ended.")
          end

          visitors = @event.visitors.verified
          return json_error("No registered visitors for this event yet.") if visitors.empty?

          # Exclude already-won visitors for fairness.
          # If all visitors have won, reset the pool for a new cycle.
          already_won_ids = LuckyDrawResult.where(event_id: @event.id).pluck(:visitor_id)
          pool = visitors.where.not(id: already_won_ids)
          pool = visitors if pool.empty?

          winner = pool.order("RANDOM()").first
          result = LuckyDrawResult.create!(
            event:    @event,
            visitor:  winner,
            drawn_by: @current_organizer
          )
          json_success(result_data(result))
        end

        # DELETE /api/v1/organizer/events/:event_id/lucky_draw_results
        def destroy_all
          LuckyDrawResult.where(event_id: @event.id).delete_all
          json_success({ message: "Lucky draw results cleared." })
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
