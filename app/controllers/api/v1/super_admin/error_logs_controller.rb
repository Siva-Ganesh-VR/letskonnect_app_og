# app/controllers/api/v1/super_admin/error_logs_controller.rb
module Api
  module V1
    module SuperAdmin
      class ErrorLogsController < ApplicationController
        before_action :authenticate_super_admin!

        # GET /api/v1/super_admin/error_logs
        def index
          logs = ErrorLog.all

          # Filters
          logs = logs.where(source:   params[:source])   if params[:source].present?
          logs = logs.where(severity: params[:severity]) if params[:severity].present?
          logs = logs.where(resolved: params[:resolved] == "true") if params[:resolved].present?
          logs = logs.where(event_id: params[:event_id]) if params[:event_id].present?

          if params[:search].present?
            q    = "%#{params[:search]}%"
            logs = logs.where("message ILIKE ? OR error_type ILIKE ? OR endpoint ILIKE ?", q, q, q)
          end

          if params[:from].present?
            logs = logs.where("created_at >= ?", Time.parse(params[:from]))
          end
          if params[:to].present?
            logs = logs.where("created_at <= ?", Time.parse(params[:to]))
          end

          logs = logs.recent

          # Summary counts
          summary = {
            total:      ErrorLog.count,
            unresolved: ErrorLog.unresolved.count,
            errors:     ErrorLog.where(severity: "error").count,
            warnings:   ErrorLog.where(severity: "warning").count,
            by_source:  ErrorLog.group(:source).count,
          }

          pagy, paginated = pagy(logs, items: params[:per_page] || 50)

          json_success(
            paginated.map { |l| log_data(l) },
            meta: {
              total:    pagy.count,
              page:     pagy.page,
              per_page: pagy.items,
              pages:    pagy.pages,
              summary:  summary,
            }
          )
        end

        # GET /api/v1/super_admin/error_logs/:id
        def show
          log = ErrorLog.find(params[:id])
          json_success(log_data(log, full: true))
        end

        # PATCH /api/v1/super_admin/error_logs/:id/resolve
        def resolve
          log = ErrorLog.find(params[:id])
          log.update!(
            resolved:         true,
            resolved_at:      Time.current,
            resolution_note:  params[:note]
          )
          json_success({ message: "Marked as resolved.", log: log_data(log) })
        end

        # PATCH /api/v1/super_admin/error_logs/resolve_all
        def resolve_all
          scope = ErrorLog.unresolved
          scope = scope.where(source: params[:source]) if params[:source].present?
          count = scope.count
          scope.update_all(resolved: true, resolved_at: Time.current)
          json_success({ message: "#{count} errors marked as resolved." })
        end

        # DELETE /api/v1/super_admin/error_logs/clear_resolved
        def clear_resolved
          count = ErrorLog.where(resolved: true).delete_all
          json_success({ message: "Deleted #{count} resolved error logs." })
        end

        private

        def log_data(l, full: false)
          data = {
            id:             l.id,
            source:         l.source,
            severity:       l.severity,
            error_type:     l.error_type,
            status_code:    l.status_code,
            message:        l.message,
            endpoint:       l.endpoint,
            http_method:    l.http_method,
            job_class:      l.job_class,
            job_id:         l.job_id,
            event_id:       l.event_id,
            visitor_id:     l.visitor_id,
            stall_owner_id: l.stall_owner_id,
            organizer_id:   l.organizer_id,
            user_type:      l.user_type,
            ip_address:     l.ip_address,
            resolved:       l.resolved,
            resolved_at:    l.resolved_at&.iso8601,
            resolution_note: l.resolution_note,
            occurred_at:    l.created_at.iso8601,
          }

          if full
            data.merge!(
              backtrace:       l.backtrace,
              context:         l.context_parsed,
              request_params:  l.request_params_parsed,
              user_agent:      l.user_agent,
              request_id:      l.request_id,
            )
          end

          data
        end
      end
    end
  end
end
