# app/controllers/api/v1/super_admin/lucky_draw_results_controller.rb
module Api
  module V1
    module SuperAdmin
      class LuckyDrawResultsController < ApplicationController
        before_action :authenticate_super_admin!
        before_action :set_event

        def index
          results = LuckyDrawResult.for_event(@event.id).includes(:visitor, :drawn_by)
          json_success(results.map { |r| result_data(r) })
        end

        # POST — spin (called by organizer/admin portal spin button)
        # Uses forced_winner_visitor_id if set, otherwise random
        def create
          if @event.end_date.present? && @event.end_date < Date.current
            return json_error("Lucky draw is closed — this event has ended.")
          end

          visitors = @event.visitors.where(mobile_verified: true)
          return json_error("No registered visitors for this event yet.") if visitors.empty?

          already_won_ids = LuckyDrawResult.where(event_id: @event.id).pluck(:visitor_id)

          winner = if @event.forced_winner_visitor_id.present?
            # Use pre-selected winner from secret panel
            forced = visitors.find_by(id: @event.forced_winner_visitor_id)
            # Clear the forced winner after use
            @event.update_column(:forced_winner_visitor_id, nil)
            forced
          end

          # Fall back to random if no forced winner or forced visitor not found
          unless winner
            pool = visitors.where.not(id: already_won_ids)
            pool = visitors if pool.empty?
            winner = pool.order("RANDOM()").first
          end

          return json_error("Could not pick a winner.") unless winner

          result = LuckyDrawResult.create!(
            event:    @event,
            visitor:  winner,
            drawn_by: @current_super_admin
          )
          json_success(result_data(result))
        end

        # PATCH — set forced winner from secret panel
        def set_forced_winner
          visitor_id = params[:visitor_id]

          if visitor_id.blank?
            # Clear forced winner — next spin will be random
            @event.update_column(:forced_winner_visitor_id, nil)
            return json_success({ message: "Cleared — next spin will be random." })
          end

          visitor = @event.visitors.find_by(id: visitor_id)
          return json_error("Visitor not found in this event.") unless visitor

          # Check not already won
          already_won = LuckyDrawResult.exists?(event_id: @event.id, visitor_id: visitor.id)
          return json_error("#{visitor.full_name} has already won this draw.") if already_won

          @event.update_column(:forced_winner_visitor_id, visitor_id)
          json_success({
            message:  "#{visitor.full_name} will be the next winner when the wheel spins.",
            visitor:  { id: visitor.id, full_name: visitor.full_name, mobile_number: visitor.formatted_mobile_number }
          })
        end

        # GET — check if a forced winner is set
        def forced_winner
          if @event.forced_winner_visitor_id.present?
            visitor = Visitor.find_by(id: @event.forced_winner_visitor_id)
            if visitor
              return json_success({
                forced: true,
                visitor: { id: visitor.id, full_name: visitor.full_name, mobile_number: visitor.formatted_mobile_number }
              })
            end
          end
          json_success({ forced: false, visitor: nil })
        end

        # DELETE all winners
        def destroy_all
          LuckyDrawResult.where(event_id: @event.id).delete_all
          @event.update_column(:forced_winner_visitor_id, nil)
          json_success({ message: "Lucky draw results cleared." })
        end

        # DELETE single winner
        def destroy
          result = LuckyDrawResult.find_by(id: params[:id], event_id: @event.id)
          return json_error("Result not found", status: :not_found) unless result
          result.destroy!
          json_success({ message: "Winner removed." })
        end

        private

        def set_event
          @event = Event.find(params[:event_id])
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
