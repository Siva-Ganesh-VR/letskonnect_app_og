class BniWhatsappFlowService
  BUSINESS_CATEGORY_OPTIONS = {
    "1" => "Manufacturing",
    "2" => "Trading",
    "3" => "Services",
    "4" => "IT / Software",
    "5" => "Professional Services",
    "6" => "Other",

    "manufacturing" => "Manufacturing",
    "trading" => "Trading",
    "services" => "Services",
    "it" => "IT / Software",
    "it / software" => "IT / Software",
    "software" => "IT / Software",
    "professional services" => "Professional Services",
    "other" => "Other"
  }.freeze

  def initialize(visitor, message_body)
    @visitor = visitor
    @message = message_body.to_s.strip
  end

  def process
    case @visitor.whatsapp_state
    when "start"
      ask_name

    when "bni_ask_name"
      save_name

    when "bni_ask_category"
      save_category

    when "bni_ask_chapter"
      save_chapter

    when "bni_ask_region"
      save_region
    end
  end

  private

  def ask_name
    @visitor.update!(whatsapp_state: "bni_ask_name")

    WhatsappService.send_message(
      @visitor.mobile_number,
      "👋 Welcome to the BNI registration! What is your Name?"
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

  save_answer("bni_name", @message)

    @visitor.update!(
      full_name: @message.titleize,
      whatsapp_state: "bni_ask_category"
    )

    WhatsappService.send_message(
      @visitor.mobile_number,
      "📂 What is your Business Category?\n\n" \
      "1. Manufacturing\n" \
      "2. Trading\n" \
      "3. Services\n" \
      "4. IT / Software\n" \
      "5. Professional Services\n" \
      "6. Other"
    )
  end

  def save_category
    category = BUSINESS_CATEGORY_OPTIONS[normalized_message]

    unless category
      WhatsappService.send_message(
        @visitor.mobile_number,
        "Please select a valid business category:\n\n" \
        "1. Manufacturing\n" \
        "2. Trading\n" \
        "3. Services\n" \
        "4. IT / Software\n" \
        "5. Professional Services\n" \
        "6. Other"
      )
      return
    end

    save_answer("bni_category", category)

    @visitor.update!(
      business_category: category,
      whatsapp_state: "bni_ask_chapter"
    )

    WhatsappService.send_message(
      @visitor.mobile_number,
      "🏢 Please enter your Chapter Name."
    )
  end

  def save_chapter
    if @message.blank?
      WhatsappService.send_message(
        @visitor.mobile_number,
        "Please enter your Chapter Name."
      )
      return
    end

    save_answer("bni_chapter", @message)

    @visitor.update!(
      whatsapp_state: "bni_ask_region"
    )

    WhatsappService.send_message(
      @visitor.mobile_number,
      "🌍 Please enter your Region."
    )
  end

  def save_region
    if @message.blank?
      WhatsappService.send_message(
        @visitor.mobile_number,
        "Please enter your Region."
      )
      return
    end

    save_answer("bni_region", @message)

    @visitor.update!(
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

  def normalized_message
    @message
      .to_s
      .downcase
      .tr("_-", " ")
      .gsub(/\s+/, " ")
      .strip
  end
end