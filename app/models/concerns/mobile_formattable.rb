module MobileFormattable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_mobile_number
  end

  def mobile_number
    return if self[:mobile_number].blank?

    "+91 #{self[:mobile_number]}"
  end

  private

  def normalize_mobile_number
    return if self[:mobile_number].blank?

    number = self[:mobile_number].to_s

    # Keep only digits
    number = number.gsub(/\D/, "")

    # Remove leading zeros (0091..., 091..., etc.)
    number = number.sub(/^0+/, "")

    # Remove country code if present
    number = number.sub(/^91/, "") if number.length > 10

    # Keep only the last 10 digits
    number = number.last(10)

    self[:mobile_number] = number
  end
end