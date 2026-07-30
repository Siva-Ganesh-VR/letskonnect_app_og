module Api
  module V1
    module SuperAdmin
      class TemplatesController < ApplicationController
        before_action :authenticate_super_admin!

        def index
          templates = Template.order(created_at: :desc)
          templates = templates.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
          templates = templates.where("template_type = ?", "#{params[:template_type]}") if params[:template_type].present?
          pagy, paged = pagy(templates, items: 10)
          json_success(paged.map { |t| template_resp(t) }, meta: { total: pagy.count, pages: pagy.pages })
        end
        
        def create
          template = nil

          ActiveRecord::Base.transaction do
            template = Template.create!(template_params)

            create_template_questions(template.id) if params[:template_questions].present?
            create_template_message(template.id) if params[:template_message].present?
          end

          json_success(template_resp(template), status: :created)
        end

        def show
          template = Template.find(params[:id])
          response = template_resp(template)

          if template.template_type == "question"
            response[:questions] = template.template_questions
          elsif template.template_type == "message"
            response[:message] = template.template_messages.first&.message
          end

          json_success(response)
        end

        def destroy
          t = Template.find(params[:id])
          t.update!(active: false)
          json_success({ message: "Template deactivated" })
        end

        def create_template_questions(template_id)
          params[:template_questions].each_with_index do |row, index|
            question = TemplateQuestion.new(template_question_params(row))

            question.template_id = template_id
            question.display_order = index + 1
            question.save!
          end
        end

        def create_template_message(template_id)
          TemplateMessage.create!(
            template_id: template_id,
            message: params[:template_message]
          )
        end

        private

        def template_params
          params.require(:template).permit(
            :name, :template_type
          )
        end

        def template_question_params(row)
          row.permit(
            :question,
            :field_type,
            :required,
            :options
          )
        end

        def template_resp(t)
          { id: t.id, name: t.name.titleize, template_type: t.template_type, active: t.active }
        end
      end
    end
  end
end
