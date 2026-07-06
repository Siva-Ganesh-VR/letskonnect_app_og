class WhatsappFlowService
  CATEGORY_OPTIONS = {
    "1" => "Clothing",
    "2" => "Gold Jewellery",
    "3" => "Manufacturing",
    "4" => "Services",
    "5" => "BNI Member",
    "6" => "Other",

    "clothing" => "Clothing",
    "gold jewellery" => "Gold Jewellery",
    "gold jewelry" => "Gold Jewellery",
    "manufacturing" => "Manufacturing",
    "services" => "Services",
    "bni member" => "BNI Member",
    "other" => "Other"
  }.freeze

  LOOKING_FOR_OPTIONS = {
    "1" => "Business Networking",
    "2" => "Suppliers",
    "3" => "Distributors",
    "4" => "Customers",
    "5" => "Partnerships",
    "6" => "Investment",

    "business networking" => "Business Networking",
    "networking" => "Business Networking",
    "suppliers" => "Suppliers",
    "distributors" => "Distributors",
    "customers" => "Customers",
    "partnerships" => "Partnerships",
    "investment" => "Investment"
  }.freeze

  YES_VALUES = %w[
    yes y yeah yep true 1
  ].freeze

  NO_VALUES = %w[
    no n nope false 0
  ].freeze

  def initialize(visitor, message_body)
    @visitor = visitor
    @message = message_body.to_s.strip
  end

  def process
    @visitor.with_lock do
      @visitor.reload

      case @visitor.whatsapp_state
      when "start"
        ask_name

      when "ask_name"
        save_name

      when "ask_location"
        save_location

      when "ask_category"
        save_category

      when "ask_looking_for"
        save_looking_for

      when "ask_decision"
        save_decision
      end
    end
  end

  private

  def ask_name
    @visitor.update!(whatsapp_state: "ask_name")

    WhatsappService.send_message(
      @visitor.mobile_number,
      "👋 Welcome! What is your Name?"
    )
  end

  def save_name
    if @message.blank?
      WhatsappService.send_message(
        @visitor.mobile_number,
        "Please enter your name."
      )
      return
    end

    save_answer("name", @message)

    @visitor.update!(
      full_name: @message.titleize,
      whatsapp_state: "ask_location"
    )

    WhatsappService.send_message(
      @visitor.mobile_number,
      "📍 Where are you located?"
    )
  end

  def save_location
    if @message.blank?
      WhatsappService.send_message(
        @visitor.mobile_number,
        "Please enter your location."
      )
      return
    end

    save_answer("location", @message)

    @visitor.update!(
      location: @message,
      whatsapp_state: "ask_category"
    )

    WhatsappService.send_template(
      @visitor.mobile_number,
      ENV["TWILIO_CATEGORY_TEMPLATE_SID"]
    )
  end

  def save_category
    category = CATEGORY_OPTIONS[normalized_message]

    unless category
      WhatsappService.send_template(
        @visitor.mobile_number,
        ENV["TWILIO_CATEGORY_TEMPLATE_SID"]
      )
      return
    end

    save_answer("category", category)

    @visitor.update!(
      business_category: category,
      whatsapp_state: "ask_looking_for"
    )

    WhatsappService.send_template(
      @visitor.mobile_number,
      ENV["TWILIO_LOOKING_FOR_TEMPLATE_SID"]
    )
  end

  def save_looking_for
    looking_for = LOOKING_FOR_OPTIONS[normalized_message]

    unless looking_for
      WhatsappService.send_template(
        @visitor.mobile_number,
        ENV["TWILIO_LOOKING_FOR_TEMPLATE_SID"]
      )
      return
    end

    save_answer("looking_for", looking_for)

    @visitor.update!(
      looking_for: looking_for,
      whatsapp_state: "ask_decision"
    )

    WhatsappService.send_template(
      @visitor.mobile_number,
      ENV["TWILIO_QUICK_REPLY_TEMPLATE_SID"],
      {
        "quick_reply_msg_body" =>
          "🧑‍💼 Are you a Business Owner / Decision Maker?"
      }
    )
  end

  def save_decision
    value = normalized_message

    decision =
      if YES_VALUES.include?(value)
        true
      elsif NO_VALUES.include?(value)
        false
      else
        nil
      end

    if decision.nil?
      WhatsappService.send_template(
        @visitor.mobile_number,
        ENV["TWILIO_QUICK_REPLY_TEMPLATE_SID"],
        {
          "quick_reply_msg_body" =>
            "🧑‍💼 Are you a Business Owner / Decision Maker?"
        }
      )
      return
    end

    save_answer("decision", decision ? "Yes" : "No")

    @visitor.update!(
      decision_maker: decision,
      whatsapp_state: "completed",
      whatsapp_completed_at: Time.current,
      mobile_verified: true
    )

    WhatsappService.send_registration_confirmation(@visitor)
  end

  def save_answer(question_key, answer)
    VisitorAnswer.find_or_initialize_by(
      visitor: @visitor,
      question_key: question_key
    ).tap do |record|
      record.answer = answer
      record.save!
    end
  end

  private

  def normalized_message
    @message
      .to_s
      .downcase
      .tr("_-", "  ")      # Convert _ and - to spaces
      .gsub(/\s+/, " ")    # Collapse multiple spaces
      .strip
  end
end