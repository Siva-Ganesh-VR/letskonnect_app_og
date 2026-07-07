require 'rails_helper'

RSpec.describe StallType, type: :model do
  it 'requires a name' do
    record = described_class.new
    expect(record).not_to be_valid
  end
end
