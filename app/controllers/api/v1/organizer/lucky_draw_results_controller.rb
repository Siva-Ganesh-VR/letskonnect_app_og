# app/controllers/api/v1/organizer/lucky_draw_results_controller.rb
module Api
  module V1
    module Organizer
      class LuckyDrawResultsController < ApplicationController
        before_action :authenticate_organizer!
        before_action :set_event

        # GET /api/v1/organizer/events/:event_id/lucky_draw_results
        # Returns both regular and bumper results
        def index
          results = LuckyDrawResult
            .for_event(@event.id)
            .includes(:visitor, :drawn_by)
          json_success(results.map { |r| result_data(r) })
        end

        # POST /api/v1/organizer/events/:event_id/lucky_draw_results
        # Regular draw — time-window based
        def create
          if @event.end_date.present? && @event.end_date < Date.current
            return json_error("Lucky draw is closed — this event has ended.")
          end

          visitors = @event.visitors.verified
          return json_error("No registered visitors for this event yet.") if visitors.empty?

          # ── All-time winners (regular + bumper) — never repeat ─────────────
          all_won_ids = LuckyDrawResult.where(event_id: @event.id).pluck(:visitor_id).uniq

          # ── Find the window start ──────────────────────────────────────────
          # Window start = created_at of last regular draw result, or event start
          last_regular = LuckyDrawResult
            .where(event_id: @event.id, draw_type: "regular")
            .order(created_at: :desc)
            .first

          # window_start = last_regular&.window_end || @event.created_at
          window_start = last_regular&.window_end || @event.created_at
          window_end   = Time.current

          # ── Build pool: registered in window, not already won ──────────────
          pool = visitors
            .where(created_at: window_start..window_end)
            .where.not(id: all_won_ids)

          # ── If window is empty, fall back to previous batch ────────────────
          # (per requirement: "get from previous batch")
          if pool.empty?
            # Window is empty — fall back to all undrawn visitors from any time
            pool = visitors.where.not(id: all_won_ids)
            return json_error("No eligible visitors found. All #{visitors.count} have already won.") if pool.empty?
            # Keep window_start as-is so next draw starts a fresh window from now
          end

          # ── Forced winner (secret panel) ───────────────────────────────────
          winner = if @event.forced_winner_visitor_id.present?
            forced = pool.find_by(id: @event.forced_winner_visitor_id)
            @event.update_column(:forced_winner_visitor_id, nil)
            forced
          end

          # ── Random pick ────────────────────────────────────────────────────
          winner ||= pool.order("RANDOM()").first
          return json_error("Could not pick a winner.") unless winner

          result = LuckyDrawResult.create!(
            event:        @event,
            visitor:      winner,
            drawn_by:     @current_organizer,
            draw_type:    "regular",
            window_start: window_start,
            window_end:   window_end
          )

          json_success(result_data(result))
        end

        # POST /api/v1/organizer/events/:event_id/lucky_draw_results/bumper
        # Bumper draw — picks from ALL registered visitors, no repeat winners
        def bumper
          if @event.end_date.present? && @event.end_date < Date.current
            return json_error("Lucky draw is closed — this event has ended.")
          end

          visitors = @event.visitors.verified
          return json_error("No registered visitors for this event yet.") if visitors.empty?

          # All-time winners (regular + bumper) — never repeat
          all_won_ids = LuckyDrawResult.where(event_id: @event.id).pluck(:visitor_id).uniq

          pool = visitors.where.not(id: all_won_ids)

          if pool.empty?
            return json_error(
              "All #{visitors.count} registered visitor(s) have already won. " \
              "Clear the results to start a new draw."
            )
          end

          winner = if @event.forced_winner_visitor_id.present?
            forced = pool.find_by(id: @event.forced_winner_visitor_id)
            @event.update_column(:forced_winner_visitor_id, nil)
            forced
          end
          winner ||= pool.order("RANDOM()").first
          return json_error("Could not pick a winner.") unless winner

          result = LuckyDrawResult.create!(
            event:     @event,
            visitor:   winner,
            drawn_by:  @current_organizer,
            draw_type: "bumper"
          )

          json_success(result_data(result))
        end

        # DELETE /api/v1/organizer/events/:event_id/lucky_draw_results
        # Clears all results (regular + bumper)
        def destroy_all
          LuckyDrawResult.where(event_id: @event.id).delete_all
          @event.update_column(:forced_winner_visitor_id, nil)
          json_success({ message: "All lucky draw results cleared." })
        end

        # DELETE /api/v1/organizer/events/:event_id/lucky_draw_results/:id
        def destroy
          result = LuckyDrawResult.find_by(id: params[:id], event_id: @event.id)
          return json_error("Result not found", status: :not_found) unless result
          result.destroy!
          json_success({ message: "Winner removed." })
        end

        # PATCH — set forced winner from secret panel (ldsecret.html)
        def set_forced_winner
          visitor_id = params[:visitor_id]

          if visitor_id.blank?
            @event.update_column(:forced_winner_visitor_id, nil)
            return json_success({ message: "Cleared — next spin will be random." })
          end

          visitor = @event.visitors.find_by(id: visitor_id)
          return json_error("Visitor not found in this event.") unless visitor

          already_won = LuckyDrawResult.exists?(event_id: @event.id, visitor_id: visitor.id)
          return json_error("#{visitor.full_name} has already won this draw.") if already_won

          @event.update_column(:forced_winner_visitor_id, visitor_id)
          json_success({
            message: "#{visitor.full_name} will be the next winner when the wheel spins.",
            visitor: { id: visitor.id, full_name: visitor.full_name, mobile_number: visitor.formatted_mobile_number }
          })
        end

        # GET — check if a forced winner is currently set
        def forced_winner
          if @event.forced_winner_visitor_id.present?
            visitor = Visitor.find_by(id: @event.forced_winner_visitor_id)
            if visitor
              return json_success({
                forced:  true,
                visitor: { id: visitor.id, full_name: visitor.full_name, mobile_number: visitor.formatted_mobile_number }
              })
            end
          end
          json_success({ forced: false, visitor: nil })
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
            draw_type:     r.draw_type,
            drawn_at:      r.created_at.iso8601,
            drawn_by:      drawn_by_name,
            drawn_by_type: r.drawn_by_type,
            window_start:  r.window_start&.iso8601,
            window_end:    r.window_end&.iso8601,
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
