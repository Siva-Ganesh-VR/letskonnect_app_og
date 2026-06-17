puts "🌱 Seeding LetsKonnect..."

puts "\n👑 Creating Super Admin..."
admin = SuperAdmin.find_or_initialize_by(email: "admin@letskonnect.in")
admin.assign_attributes(name: "LetsKonnect Admin", password: "Admin@1234", password_confirmation: "Admin@1234")
admin.jti = SecureRandom.uuid if admin.jti.blank?
admin.save!
puts "   ✅ admin@letskonnect.in  /  Admin@1234"

puts "\n🏢 Creating Event Organizer..."
organizer = EventOrganizer.find_or_initialize_by(email: "organizer@techfest.com")
organizer.assign_attributes(
  name: "Priya Sharma", mobile_number: "9876543210",
  company_name: "TechFest Events",
  password: "Organizer@123", password_confirmation: "Organizer@123",
  super_admin: admin
)
organizer.jti = SecureRandom.uuid if organizer.jti.blank?
organizer.save!
puts "   ✅ organizer@techfest.com  /  Organizer@123"

puts "\n🎪 Creating Events..."
event = Event.find_or_initialize_by(slug: "chennai-tech-expo-2024")
event.assign_attributes(
  name: "Chennai Tech Expo 2024",
  description: "Tamil Nadu's largest technology and business exhibition — 3 days of innovation, networking and growth.",
  venue: "Chennai Trade Centre, Nandambakkam",
  city: "Chennai",
  start_date: Date.today + 7.days,
  end_date: Date.today + 9.days,
  status: "active",
  event_organizer: organizer
)
event.registration_qr_token = SecureRandom.urlsafe_base64(32) if event.registration_qr_token.blank?
event.save!
EventAnalytics.find_or_create_by!(event: event)
puts "   ✅ #{event.name}"
puts "   🔗 Registration URL: http://localhost:3000/register/#{event.registration_qr_token}"

event2 = Event.find_or_initialize_by(slug: "bni-business-connect-2024")
event2.assign_attributes(
  name: "BNI Business Connect 2024",
  description: "Premier BNI networking event for entrepreneurs and business professionals.",
  venue: "Hotel ITC Grand Chola",
  city: "Chennai",
  start_date: Date.today + 14.days,
  end_date: Date.today + 14.days,
  status: "draft",
  event_organizer: organizer
)
event2.registration_qr_token = SecureRandom.urlsafe_base64(32) if event2.registration_qr_token.blank?
event2.save!
EventAnalytics.find_or_create_by!(event: event2)
puts "   ✅ #{event2.name}"

puts "\n🏪 Creating Stall Owners..."
stall_data = [
  { name: "Arjun Kumar",      mobile: "9876541001", company: "CloudTech Solutions",    stall: "A1",  category: "IT Services" },
  { name: "Kavitha Rajan",    mobile: "9876541002", company: "Digital Marketing Pro",  stall: "A2",  category: "Marketing" },
  { name: "Suresh Babu",      mobile: "9876541003", company: "Fintech Innovations",    stall: "B1",  category: "Finance" },
  { name: "Anitha Meenakshi", mobile: "9876541004", company: "EduTech Academy",        stall: "B2",  category: "Education" },
  { name: "Rajesh Pillai",    mobile: "9876541005", company: "Green Energy Corp",      stall: "C1",  category: "Energy" },
  { name: "Deepa Krishnan",   mobile: "9876541006", company: "HealthCare Plus",        stall: "C2",  category: "Healthcare" },
  { name: "Venkat Subbu",     mobile: "9876541007", company: "Retail Connect",         stall: "D1",  category: "Retail" },
  { name: "Sathya Moorthy",   mobile: "9876541008", company: "Logistics Express",      stall: "D2",  category: "Logistics" },
]

stall_data.each do |s|
  stall = StallOwner.find_or_initialize_by(mobile_number: s[:mobile], event: event)
  stall.assign_attributes(
    name: s[:name], company_name: s[:company],
    stall_number: s[:stall], stall_category: s[:category],
    password: "Stall@1234", password_confirmation: "Stall@1234",
    event_organizer: organizer, active: true
  )
  stall.jti = SecureRandom.uuid if stall.jti.blank?
  stall.save!
  StallAnalytics.find_or_create_by!(stall_owner: stall, event: event)
  puts "   ✅ #{s[:company]} (#{s[:stall]}) — #{s[:mobile]}"
end

puts "\n👥 Creating Sample Visitors..."
visitor_data = [
  { name: "Mohan Raj",       mobile: "9500001001", profession: "Software Engineer", business: "TCS",           category: "IT Services",  location: "Chennai" },
  { name: "Sujatha Devi",    mobile: "9500001002", profession: "Marketing Manager", business: "Cognizant",     category: "IT Services",  location: "Bangalore" },
  { name: "Karthik Sundaram",mobile: "9500001003", profession: "Entrepreneur",      business: "StartupHub",    category: "Startup",      location: "Chennai" },
  { name: "Meena Pradeep",   mobile: "9500001004", profession: "Doctor",            business: "Apollo Clinic", category: "Healthcare",   location: "Coimbatore" },
  { name: "Ravi Shankar",    mobile: "9500001005", profession: "CFO",               business: "FinServe Ltd",  category: "Finance",      location: "Chennai" },
]

visitor_data.each do |v|
  visitor = Visitor.find_or_initialize_by(mobile_number: v[:mobile], event: event)
  visitor.assign_attributes(
    full_name: v[:name], location: v[:location],
    profession: v[:profession], business_name: v[:business],
    business_category: v[:category], mobile_verified: true
  )
  if visitor.qr_token.blank?
    prefix = event.name.upcase.gsub(/[^A-Z]/,"").first(3).ljust(3,"X")
    visitor.visitor_id_code = "#{prefix}#{SecureRandom.alphanumeric(8).upcase}"
    visitor.qr_token        = SecureRandom.urlsafe_base64(32)
  end
  visitor.save!
  puts "   ✅ #{v[:name]} — #{v[:mobile]}"
end

puts "\n📊 Creating Sample Leads..."
stalls    = event.stall_owners.first(3)
visitors  = event.visitors.verified
temps     = %w[hot warm cold]
statuses  = %w[new contacted interested follow_up converted]

visitors.each_with_index do |visitor, vi|
  stalls.each_with_index do |stall, si|
    next if si > vi  # not all visitors visit all stalls
    Lead.find_or_create_by!(visitor: visitor, stall_owner: stall) do |l|
      l.event           = event
      l.temperature     = temps.sample
      l.interest_rating = rand(2..5)
      l.status          = statuses.sample
      l.scanned_at      = rand(1..72).hours.ago
      l.notes           = ["Interested in cloud migration", "Follow up next week", "Needs demo", nil].sample
    end
  end
end

# Sync counters
event.stall_owners.each do |stall|
  StallOwner.where(id: stall.id).update_all(total_leads_count: stall.leads.count)
end
Event.where(id: event.id).update_all(registered_count: event.visitors.where(mobile_verified: true).count)

# Update analytics
begin
  AnalyticsService.update_event_analytics(event.id) if defined?(AnalyticsService)
rescue => e
  puts "   ⚠️  Analytics update skipped: #{e.message}"
end

puts "\n" + "="*55
puts "✅ SEED COMPLETE"
puts "="*55
puts ""
puts "Super Admin:    admin@letskonnect.in       / Admin@1234"
puts "Organizer:      organizer@techfest.com      / Organizer@123"
puts "Stall Owners:   9876541001..008             / Stall@1234"
puts ""
puts "Active Event:   Chennai Tech Expo 2024"
puts "Visitors:       5 verified visitors"
puts "Sample Leads:   ~#{Lead.count} leads"
puts ""
puts "Start server:   bin/rails server"
puts "Sidekiq:        bundle exec sidekiq -C config/sidekiq.yml"
puts "="*55
