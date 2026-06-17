namespace :letskonnect do
  desc "Block an IP address from the platform"
  task :block_ip, [:ip] => :environment do |_t, args|
    ip = args[:ip]
    abort "Usage: rake letskonnect:block_ip[1.2.3.4]" unless ip
    Rack::Attack.cache.write("blocked_ip:#{ip}", true)
    puts "Blocked IP: #{ip}"
  end

  desc "Unblock an IP address"
  task :unblock_ip, [:ip] => :environment do |_t, args|
    ip = args[:ip]
    abort "Usage: rake letskonnect:unblock_ip[1.2.3.4]" unless ip
    Rack::Attack.cache.delete("blocked_ip:#{ip}")
    puts "Unblocked IP: #{ip}"
  end

  desc "Force refresh analytics for all active events"
  task refresh_analytics: :environment do
    Event.active_events.each do |event|
      AnalyticsService.update_event_analytics(event.id)
      puts "Refreshed analytics for: #{event.name}"
    end
  end

  desc "Send test WhatsApp message"
  task :test_whatsapp, [:mobile] => :environment do |_t, args|
    mobile = args[:mobile]
    abort "Usage: rake letskonnect:test_whatsapp[9876543210]" unless mobile
    result = WhatsappService.send_message(mobile, "Hello from LetsKonnect! Your WhatsApp integration is working. 🎉")
    puts result[:success] ? "Sent! SID: #{result[:sid]}" : "Failed: #{result[:error]}"
  end

  desc "Show platform statistics"
  task stats: :environment do
    puts "\n=== LetsKonnect Platform Stats ==="
    puts "Events:         #{Event.count} (#{Event.active_events.count} active)"
    puts "Organizers:     #{EventOrganizer.count}"
    puts "Stall Owners:   #{StallOwner.count}"
    puts "Visitors:       #{Visitor.verified.count} verified"
    puts "Leads:          #{Lead.count} total"
    puts "  Hot:          #{Lead.hot.count}"
    puts "  Converted:    #{Lead.converted.count}"
    puts "Notifications:  #{Notification.count} sent"
    puts "Export Jobs:    #{ExportJob.completed.count} completed"
    puts "=================================\n"
  end
end
