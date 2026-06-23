# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_06_23_060011) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "event_analytics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.integer "total_visitors", default: 0
    t.integer "total_leads", default: 0
    t.integer "total_scans", default: 0
    t.integer "hot_leads", default: 0
    t.integer "warm_leads", default: 0
    t.integer "cold_leads", default: 0
    t.jsonb "visitors_by_category", default: {}
    t.jsonb "visitors_by_location", default: {}
    t.jsonb "visitors_by_profession", default: {}
    t.jsonb "hourly_registrations", default: {}
    t.jsonb "stall_performance", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_analytics_on_event_id", unique: true
  end

  create_table "event_organizers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "mobile_number", null: false
    t.string "password_digest", null: false
    t.string "jti", null: false
    t.string "company_name"
    t.string "logo_url"
    t.boolean "active", default: true, null: false
    t.uuid "super_admin_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_event_organizers_on_active"
    t.index ["email"], name: "index_event_organizers_on_email", unique: true
    t.index ["jti"], name: "index_event_organizers_on_jti", unique: true
    t.index ["mobile_number"], name: "index_event_organizers_on_mobile_number"
    t.index ["super_admin_id"], name: "index_event_organizers_on_super_admin_id"
  end

  create_table "events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "venue", null: false
    t.string "city"
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.time "start_time"
    t.time "end_time"
    t.string "slug", null: false
    t.string "registration_qr_token", null: false
    t.string "qr_image_url"
    t.string "banner_url"
    t.string "logo_url"
    t.string "status", default: "draft", null: false
    t.jsonb "settings", default: {}
    t.integer "max_visitors"
    t.integer "registered_count", default: 0, null: false
    t.uuid "event_organizer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_organizer_id"], name: "index_events_on_event_organizer_id"
    t.index ["registration_qr_token"], name: "index_events_on_registration_qr_token", unique: true
    t.index ["slug"], name: "index_events_on_slug", unique: true
    t.index ["start_date"], name: "index_events_on_start_date"
    t.index ["status"], name: "index_events_on_status"
  end

  create_table "export_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "exportable_type", null: false
    t.uuid "exportable_id", null: false
    t.string "export_type", null: false
    t.string "status", default: "pending", null: false
    t.string "file_url"
    t.text "error_message"
    t.jsonb "filters", default: {}
    t.string "requested_by_type"
    t.uuid "requested_by_id"
    t.datetime "completed_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_export_jobs_on_expires_at"
    t.index ["exportable_type", "exportable_id"], name: "index_export_jobs_on_exportable_type_and_exportable_id"
    t.index ["status"], name: "index_export_jobs_on_status"
  end

  create_table "leads", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "visitor_id", null: false
    t.uuid "stall_owner_id", null: false
    t.uuid "event_id", null: false
    t.string "temperature", default: "warm", null: false
    t.integer "interest_rating", default: 3, null: false
    t.string "status", default: "new", null: false
    t.text "notes"
    t.string "requirements"
    t.decimal "budget", precision: 15, scale: 2
    t.date "follow_up_date"
    t.text "remarks"
    t.datetime "scanned_at", null: false
    t.string "scan_location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "created_at"], name: "index_leads_on_event_id_and_created_at"
    t.index ["event_id"], name: "index_leads_on_event_id"
    t.index ["follow_up_date"], name: "index_leads_on_follow_up_date"
    t.index ["scanned_at"], name: "index_leads_on_scanned_at"
    t.index ["stall_owner_id", "status"], name: "index_leads_on_stall_owner_id_and_status"
    t.index ["stall_owner_id", "temperature"], name: "index_leads_on_stall_owner_id_and_temperature"
    t.index ["stall_owner_id", "visitor_id"], name: "index_leads_on_stall_owner_id_and_visitor_id", unique: true
    t.index ["stall_owner_id"], name: "index_leads_on_stall_owner_id"
    t.index ["status"], name: "index_leads_on_status"
    t.index ["temperature"], name: "index_leads_on_temperature"
    t.index ["visitor_id"], name: "index_leads_on_visitor_id"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "notifiable_type", null: false
    t.uuid "notifiable_id", null: false
    t.string "notification_type", null: false
    t.string "channel", default: "whatsapp", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "payload", default: {}
    t.string "external_message_id"
    t.text "error_message"
    t.integer "retry_count", default: 0
    t.datetime "sent_at"
    t.datetime "delivered_at"
    t.uuid "event_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["event_id"], name: "index_notifications_on_event_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["status", "retry_count"], name: "index_notifications_on_status_and_retry_count", where: "((status)::text = 'failed'::text)"
    t.index ["status"], name: "index_notifications_on_status"
  end

  create_table "otp_verifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "mobile_number", null: false
    t.string "otp_code", null: false
    t.string "purpose", null: false
    t.boolean "used", default: false, null: false
    t.datetime "expires_at", null: false
    t.integer "attempts", default: 0, null: false
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_otp_verifications_on_expires_at"
    t.index ["mobile_number", "purpose"], name: "index_otp_verifications_on_mobile_number_and_purpose"
    t.index ["mobile_number"], name: "index_otp_verifications_on_mobile_number"
    t.index ["used", "expires_at"], name: "index_otp_verifications_on_used_and_expires_at"
  end

  create_table "stall_analytics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "stall_owner_id", null: false
    t.uuid "event_id", null: false
    t.integer "total_leads", default: 0
    t.integer "hot_leads", default: 0
    t.integer "warm_leads", default: 0
    t.integer "cold_leads", default: 0
    t.integer "converted_leads", default: 0
    t.jsonb "leads_by_hour", default: {}
    t.jsonb "leads_by_category", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_stall_analytics_on_event_id"
    t.index ["stall_owner_id", "event_id"], name: "index_stall_analytics_on_stall_owner_id_and_event_id", unique: true
    t.index ["stall_owner_id"], name: "index_stall_analytics_on_stall_owner_id"
  end

  create_table "stall_owners", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.string "mobile_number", null: false
    t.string "password_digest", null: false
    t.string "jti", null: false
    t.string "company_name", null: false
    t.string "stall_number"
    t.string "stall_category"
    t.text "description"
    t.string "logo_url"
    t.string "website"
    t.boolean "active", default: true, null: false
    t.integer "total_leads_count", default: 0, null: false
    t.uuid "event_id", null: false
    t.uuid "event_organizer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "active"], name: "index_stall_owners_on_event_id_and_active"
    t.index ["event_id", "stall_number"], name: "index_stall_owners_on_event_id_and_stall_number", unique: true, where: "(stall_number IS NOT NULL)"
    t.index ["event_id"], name: "index_stall_owners_on_event_id"
    t.index ["event_organizer_id"], name: "index_stall_owners_on_event_organizer_id"
    t.index ["jti"], name: "index_stall_owners_on_jti", unique: true
    t.index ["mobile_number"], name: "index_stall_owners_on_mobile_number"
  end

  create_table "super_admins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "jti", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_super_admins_on_email", unique: true
    t.index ["jti"], name: "index_super_admins_on_jti", unique: true
  end

  create_table "visitor_answers", force: :cascade do |t|
    t.uuid "visitor_id", null: false
    t.string "question_key", null: false
    t.text "answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["visitor_id"], name: "index_visitor_answers_on_visitor_id"
  end

  create_table "visitors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "full_name"
    t.string "mobile_number", null: false
    t.string "location"
    t.string "profession"
    t.string "business_category"
    t.string "business_name"
    t.string "designation"
    t.string "email"
    t.string "website"
    t.string "visitor_id_code"
    t.string "qr_token"
    t.string "qr_image_url"
    t.string "otp_code"
    t.datetime "otp_expires_at"
    t.boolean "mobile_verified", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "checked_in_at"
    t.uuid "event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "looking_for"
    t.boolean "decision_maker"
    t.string "whatsapp_state", default: "start"
    t.datetime "whatsapp_completed_at"
    t.index ["business_category"], name: "index_visitors_on_business_category"
    t.index ["created_at"], name: "index_visitors_on_created_at"
    t.index ["event_id", "mobile_verified"], name: "index_visitors_on_event_id_and_mobile_verified", where: "(mobile_verified = true)"
    t.index ["event_id"], name: "index_visitors_on_event_id"
    t.index ["mobile_number", "event_id"], name: "index_visitors_on_mobile_number_and_event_id", unique: true
    t.index ["qr_token"], name: "index_visitors_on_qr_token", unique: true
    t.index ["visitor_id_code"], name: "index_visitors_on_visitor_id_code", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "event_analytics", "events"
  add_foreign_key "event_organizers", "super_admins"
  add_foreign_key "events", "event_organizers"
  add_foreign_key "leads", "events"
  add_foreign_key "leads", "stall_owners"
  add_foreign_key "leads", "visitors"
  add_foreign_key "notifications", "events"
  add_foreign_key "stall_analytics", "events"
  add_foreign_key "stall_analytics", "stall_owners"
  add_foreign_key "stall_owners", "event_organizers"
  add_foreign_key "stall_owners", "events"
  add_foreign_key "visitor_answers", "visitors"
  add_foreign_key "visitors", "events"
end
