require "rails_helper"

RSpec.describe Visitor, type: :model do
  let(:event) { create(:event) }
  subject { build(:visitor, event: event) }

  describe "validations" do
    it { should validate_presence_of(:full_name) }
    it { should validate_presence_of(:mobile_number) }
    it "validates mobile number format" do
      subject.mobile_number = "1234567890"
      expect(subject).not_to be_valid
      subject.mobile_number = "9876543210"
      expect(subject).to be_valid
    end
    it "is unique per event" do
      create(:visitor, event: event, mobile_number: "9876543210")
      dup = build(:visitor, event: event, mobile_number: "9876543210")
      expect(dup).not_to be_valid
    end
  end

  describe "#generate_otp!" do
    it "sets otp_code and expiry" do
      subject.save!
      otp = subject.generate_otp!
      expect(otp).to match(/\d{6}/)
      expect(subject.otp_expires_at).to be > Time.current
    end
  end

  describe "#valid_otp?" do
    it "returns true for correct OTP" do
      subject.save!
      otp = subject.generate_otp!
      expect(subject.valid_otp?(otp)).to be true
    end
    it "returns false for wrong OTP" do
      subject.save!
      subject.generate_otp!
      expect(subject.valid_otp?("000000")).to be false
    end
  end

  describe "#verify_mobile!" do
    it "sets mobile_verified to true and increments event counter" do
      subject.save!
      subject.generate_otp!
      expect { subject.verify_mobile! }.to change { event.reload.registered_count }.by(1)
      expect(subject.mobile_verified).to be true
    end
  end
end
