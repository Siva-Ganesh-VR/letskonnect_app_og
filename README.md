# LetsKonnect — Event Lead Capture & Networking Platform

**Rails 7.2 · PostgreSQL · Redis · Sidekiq · Twilio WhatsApp**

---

## Quick Start (5 steps)

### Prerequisites
- Ruby 3.3.0  (`rbenv install 3.3.0` or `rvm install 3.3.0`)
- PostgreSQL 14+ running locally
- Redis running locally (`brew install redis && brew services start redis`)
- Bundler (`gem install bundler`)

### 1. Install dependencies
```bash
bundle install
```

### 2. Configure environment
The `.env` file is pre-filled for development. No changes needed to run locally:
```bash
# Already included — .env has development defaults
# OTPs and WhatsApp messages are printed to console in development
```

### 3. Setup database
```bash
bin/rails db:create db:migrate db:seed
```

### 4. Start the server
```bash
# Option A — Rails only (no background jobs)
bin/rails server

# Option B — With Sidekiq (QR generation, WhatsApp, exports)
# Terminal 1:
bin/rails server
# Terminal 2:
bundle exec sidekiq -C config/sidekiq.yml
```

### 5. Open the app
| URL | Description |
|-----|-------------|
| http://localhost:3000/admin | Admin Dashboard (login below) |
| http://localhost:3000/register/EVENT_TOKEN | Visitor Registration |
| http://localhost:3000/v/QR_TOKEN | Visitor Digital Pass |
| http://localhost:3000/health | Health check |
| http://localhost:3000/sidekiq | Sidekiq dashboard |

---

## Default Credentials (from seeds)

| Role | Login | Password |
|------|-------|----------|
| Super Admin | admin@letskonnect.in | Admin@1234 |
| Organizer | organizer@techfest.com | Organizer@123 |
| Stall Owner | 9876541001–008 | Stall@1234 |

---

## Registration Flow (Test)

1. Run `bin/rails db:seed` to get the active event
2. Find the event token: `bin/rails runner "puts Event.first.registration_qr_token"`
3. Open: `http://localhost:3000/register/TOKEN`
4. Fill the form — OTP will be **printed in the Rails server console**
5. Enter the OTP to get your digital pass

---

## API Quick Reference

### Visitor Registration
```
POST /api/v1/visitors/register     { event_token, visitor: { full_name, mobile_number, ... } }
POST /api/v1/visitors/verify_otp   { visitor_id, otp }
GET  /api/v1/visitors/qr/:id
```

### Stall Owner (Mobile App)
```
POST   /api/v1/stall/request_otp   { mobile_number, event_id }
POST   /api/v1/stall/verify_otp    { mobile_number, otp, event_id }
POST   /api/v1/stall_owner/scan    { qr_token }  [JWT required]
GET    /api/v1/stall_owner/leads   [JWT required]
PATCH  /api/v1/stall_owner/leads/:id
POST   /api/v1/stall_owner/leads/export
```

### Organizer
```
POST /api/v1/organizer/sign_in     { email, password }
GET  /api/v1/organizer/events
GET  /api/v1/organizer/events/:id/analytics
```

### Super Admin
```
POST /api/v1/super_admin/sign_in   { email, password }
GET  /api/v1/super_admin/dashboard
GET  /api/v1/super_admin/events
POST /api/v1/super_admin/events    { event_organizer_id, event: { ... } }
```

---

## Architecture

```
letskonnect/
├── app/
│   ├── controllers/
│   │   ├── api/v1/
│   │   │   ├── auth/              # Visitor + StallOwner auth (OTP)
│   │   │   ├── stall_owner/       # Dashboard, Scan, Leads
│   │   │   ├── organizer/         # Events, Stalls, Visitors
│   │   │   ├── super_admin/       # Full platform management
│   │   │   └── webhooks/          # Twilio status callbacks
│   │   ├── registrations_controller.rb   # Visitor registration HTML page
│   │   └── visitor_passes_controller.rb  # Digital pass HTML page
│   ├── models/                    # 11 models (has_secure_password + JWT)
│   ├── services/                  # WhatsappService, SmsService, QrService, AnalyticsService
│   ├── jobs/                      # 8 Sidekiq jobs
│   ├── channels/                  # LeadsChannel (Action Cable)
│   └── views/
│       ├── registrations/show.html.erb   # Beautiful mobile-first reg form
│       └── visitor_passes/show.html.erb  # Digital QR pass
├── public/
│   └── admin.html                 # Full admin SPA (no build step needed)
├── config/
│   ├── routes.rb
│   ├── initializers/
│   │   ├── rack_attack.rb         # Rate limiting
│   │   └── sidekiq.rb
├── db/
│   ├── migrate/                   # 11 migrations with indexes
│   └── seeds.rb                   # Full test data
├── .env                           # Development environment (ready to use)
└── Gemfile
```

---

## Production Notes
- Set real values in `.env` for Twilio, Fast2SMS, AWS S3
- Use PgBouncer for connection pooling under high load
- Set `RAILS_ENV=production` and run `RAILS_MASTER_KEY=... bin/rails assets:precompile`
- Use `foreman start -f Procfile` with Nginx as reverse proxy
