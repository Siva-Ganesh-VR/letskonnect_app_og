module MobileFormattable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_mobile_number
  end

  def formatted_mobile_number
    return if self[:mobile_number].blank?

    "+91 #{self[:mobile_number]}"
  end

  private

  def normalize_mobile_number
    return if self[:mobile_number].blank?

    self[:mobile_number] = self[:mobile_number].to_s.gsub(/\D/, "")
  end
end