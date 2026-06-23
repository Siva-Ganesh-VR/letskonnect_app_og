class WhatsappFlowService
  def initialize(visitor, message_body)
    @visitor = visitor
    @message = message_body.strip.downcase
  end

  def process
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

  private

  def ask_name
    @visitor.update!(whatsapp_state: "ask_name")

    WhatsappService.send_message(
      @visitor.mobile_number,
      "👋 Welcome! What is your Name?"
    )
  end

  def save_name
    @visitor.update!(full_name: @message.titleize, whatsapp_state: "ask_location")

    WhatsappService.send_message(
      @visitor.mobile_number,
      "📍 Where are you located?"
    )
  end

  def save_location
    save_answer("location", @message)
    @visitor.update!(location: @message, whatsapp_state: "ask_category")

    # WhatsappService.send_message(
    #   @visitor.mobile_number,
    #   "🏢 Which category best describes your business?\n1. Clothing\n2. Gold Jewellery\n3. Manufacturing\n4. Services\n5. BNI Member\n6. Other"
    # )

    WhatsappService.send_template(
      @visitor.mobile_number,
      ENV["TWILIO_CATEGORY_TEMPLATE_SID"]
    )
  end

  def save_category
    save_answer("category", @message)
    @visitor.update!(business_category: @message, whatsapp_state: "ask_looking_for")

    # WhatsappService.send_message(
    #   @visitor.mobile_number,
    #   "🤝 What are you looking for?\n1. Business Networking\n2. Suppliers\n3. Distributors\n4. Customers\n5. Partnerships\n6. Investment"
    # )

    WhatsappService.send_template(
      @visitor.mobile_number,
      ENV["TWILIO_LOOKING_FOR_TEMPLATE_SID"]
    )
  end

  def save_looking_for
    save_answer("looking_for", @message)
    @visitor.update!(looking_for: @message, whatsapp_state: "ask_decision")

    # WhatsappService.send_message(
    #   @visitor.mobile_number,
    #   "🧑‍💼 Are you a Business Owner / Decision Maker? (Yes/No)"
    # )

    WhatsappService.send_template(
      @visitor.mobile_number,
      ENV["TWILIO_QUICK_REPLY_TEMPLATE_SID"],
      { "quick_reply_msg_body" => "🧑‍💼 Are you a Business Owner / Decision Maker?" }
    )
  end

  def save_decision
    save_answer("decision", @message)
    @visitor.update!(decision_maker: @message.downcase == "yes", whatsapp_state: "completed", whatsapp_completed_at: Time.current, mobile_verified: true)

    WhatsappService.send_registration_confirmation(@visitor)

    # WhatsappService.send_message(
    #   @visitor.mobile_number,
    #   "✅ Thank you! Your registration is complete."
    # )
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
end