module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_identifier

    def connect
      self.current_user_identifier = params[:token]&.first(16) || SecureRandom.hex(8)
    end
  end
end
