# db/migrate/20260812000001_create_error_logs.rb
class CreateErrorLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :error_logs, id: :uuid do |t|
      # ── Classification ───────────────────────────────────────
      t.string  :source,        null: false  # api / sidekiq / frontend / ocr
      t.string  :severity,      null: false, default: "error"  # error / warning / info
      t.string  :error_type                  # ActiveRecord::RecordInvalid, Timeout, etc.
      t.string  :status_code                 # HTTP status: 500, 422, 404 etc.

      # ── What happened ────────────────────────────────────────
      t.text    :message,       null: false  # human-readable error message
      t.text    :backtrace                   # full stack trace
      t.text    :context                     # JSON: any extra context

      # ── Where it happened ────────────────────────────────────
      t.string  :endpoint                    # /api/v1/stall_owner/scan
      t.string  :http_method                 # GET POST PATCH DELETE
      t.text    :request_params              # JSON: sanitized params sent
      t.string  :job_class                   # QrGenerationJob etc. (for Sidekiq)
      t.string  :job_id                      # Sidekiq job ID

      # ── Who was affected ─────────────────────────────────────
      t.uuid    :event_id
      t.uuid    :visitor_id
      t.uuid    :stall_owner_id
      t.uuid    :organizer_id
      t.string  :user_type                   # visitor / stall_owner / organizer / admin

      # ── Request metadata ─────────────────────────────────────
      t.string  :ip_address
      t.string  :user_agent
      t.string  :request_id                  # Rails request UUID

      # ── Resolution ───────────────────────────────────────────
      t.boolean :resolved,    default: false
      t.text    :resolution_note
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :error_logs, :source
    add_index :error_logs, :severity
    add_index :error_logs, :resolved
    add_index :error_logs, :event_id
    add_index :error_logs, :created_at
    add_index :error_logs, [:source, :resolved, :created_at]
  end
end
