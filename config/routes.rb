Rails.application.routes.draw do
  mount ActiveStorage::Engine => "/rails/active_storage"

  # ── Health check ──────────────────────────────────────────────────────────
  get "/health", to: "health#index"

  # ── Admin SPA (served as static file) ────────────────────────────────────
  get "/admin", to: redirect("/admin.html")

  # ── Visitor-facing pages ─────────────────────────────────────────────────
  get "/register/:event_token", to: "registrations#show",   as: :event_registration
  get "/v/:qr_token",           to: "visitor_passes#show",  as: :visitor_pass

  # ── Sidekiq Web UI ────────────────────────────────────────────────────────
  require "sidekiq/web"
  require "sidekiq-scheduler/web"
  Sidekiq::Web.use(Rack::Auth::Basic) do |u, p|
    u == ENV.fetch("SIDEKIQ_USERNAME","admin") &&
    p == ENV.fetch("SIDEKIQ_PASSWORD","sidekiq_password")
  end
  mount Sidekiq::Web => "/sidekiq"

  # ── Action Cable ──────────────────────────────────────────────────────────
  mount ActionCable.server => "/cable"

  # ── API v1 ────────────────────────────────────────────────────────────────
  namespace :api do
    namespace :v1 do

      # Visitor Registration
      post   "visitors/register",       to: "auth/visitors#create"
      post   "visitors/verify_otp",     to: "auth/visitors#verify_otp"
      post   "visitors/resend_otp",     to: "auth/visitors#resend_otp"
      get    "visitors/dashboard/:id",  to: "auth/visitors#dashboard"
      get    "visitors/qr/:id",         to: "auth/visitors#qr_code"

      # Stall Owner Auth (OTP-based)
      post   "stall/sign_in",           to: "auth/stall_owners#sign_in"
      post   "stall/request_otp",       to: "auth/stall_owners#request_otp"
      post   "stall/verify_otp",        to: "auth/stall_owners#verify_otp"
      delete "stall/sign_out",          to: "auth/stall_owners#sign_out"

      # Stall Owner — protected routes
      namespace :stall_owner do
        get    "dashboard",             to: "dashboard#show"
        post   "scan",                  to: "scans#create"
        get    "scan/history",          to: "scans#history"
        resources :leads, only: [:index, :show, :update] do
          member   { post :whatsapp; post :call_log }
          collection do
            get  :summary
            post :export
            get  "export/:job_id/status", to: "leads#export_status"
          end
        end
      end

      # Organizer Auth
      post   "organizer/sign_in",       to: "organizer/sessions#create"
      delete "organizer/sign_out",      to: "organizer/sessions#destroy"

      # Organizer — protected routes
      namespace :organizer do
        # allow listing stall owners across all organizer events
        get "stall_owners", to: "stall_owners#index"
          # allow listing visitors across all organizer events
          get "visitors", to: "visitors#index"
        get "dashboard",                to: "dashboard#show"
        resources :events, only: [:index, :show, :create, :update] do
          member { get :analytics; get :qr_code; post :activate; post :archive }
          resources :stall_owners, only: [:index, :show, :create, :update, :destroy] do
            member { post :send_credentials; patch :toggle_active }
            collection do
              post :bulk_create
              post :bulk_upload
            end
          end
          resources :visitors, only: [:index, :show] do
            collection { post :export; get "export/:job_id/status", to: "visitors#export_status" }
          end
        end
      end

      # Super Admin Auth
      post   "super_admin/sign_in",     to: "super_admin/sessions#create"
      delete "super_admin/sign_out",    to: "super_admin/sessions#destroy"

      # Super Admin — protected routes
      namespace :super_admin do
        get "dashboard",                to: "dashboard#show"
        resources :events do
          member { get :analytics; post :generate_qr; post :activate; post :archive }
          resources :visitors, only: [:index]
          resources :stall_owners, only: [:index]
        end
        resources :event_organizers do
          member { patch :activate; patch :deactivate; post :reset_password; get :events }
        end
        resources :stall_owners,  only: [:index, :show, :create, :update, :destroy] do
          member { patch :activate; patch :deactivate }
          collection do
            post :bulk_create
            post :bulk_upload
          end
        end
        resources :visitors,      only: [:index, :show, :destroy]
        get "analytics/platform", to: "analytics#platform"
      end

      # Shared
      get  "scan/:qr_token",            to: "scans#show_visitor"
      get  "exports/:job_id",           to: "exports#show"

      # Webhooks
      namespace :webhooks do
        post "twilio", to: "twilio#status"
        post "/whatsapp/webhook", to: "twilio#receive"
      end
    end
  end

  # ── Fallback 404 ──────────────────────────────────────────────────────────
  # match "*path", to: proc { [404, {"Content-Type"=>"application/json"}, ['{"success":false,"error":"Not found"}']] }, via: :all
  match "*path",
    to: proc {
      [404, {"Content-Type"=>"application/json"}, ['{"success":false,"error":"Not found"}']]
    },
    via: :all,
    constraints: lambda { |req|
      !req.path.start_with?("/rails/active_storage")
    }
end
