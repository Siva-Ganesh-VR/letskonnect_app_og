class BniWhatsappFlowService
  BUSINESS_CATEGORY_OPTIONS = {
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

    WhatsappService.send_template(
      @visitor.mobile_number,
      ENV["TWILIO_CATEGORY_TEMPLATE_SID"]
    )
  end

  def save_category
    category = BUSINESS_CATEGORY_OPTIONS[normalized_message]

    unless category
      WhatsappService.send_template(
        @visitor.mobile_number,
        ENV["TWILIO_CATEGORY_TEMPLATE_SID"]
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
        "🏢 Please enter your Chapter Name."
      )
      return
    end

    save_answer("bni_chapter", @message)

    @visitor.update!(
      whatsapp_state: "bni_ask_region"
    )

    WhatsappService.send_message(
      @visitor.mobile_number,
      "🌍 Please enter your location."
    )
  end

  def save_region
    if @message.blank?
      WhatsappService.send_message(
        @visitor.mobile_number,
        "🌍 Please enter your location."
      )
      return
    end

    save_answer("bni_region", @message)

    @visitor.update!(
      location: @message,
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