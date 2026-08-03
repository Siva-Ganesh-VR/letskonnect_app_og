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

        def update
          template = Template.find(params[:id])

          ActiveRecord::Base.transaction do
            template.update!(template_params)

            if template.template_type == "question"
              template.template_questions.destroy_all
              create_template_questions(template.id) if params[:template_questions].present?

            elsif template.template_type == "message"
              if params[:template_message].present?
                if template.template_messages.present?
                  template.template_messages.first.update!(message: params[:template_message])
                else
                  create_template_message(template.id)
                end
              end
            end
          end

          json_success(template_resp(template.reload))
        end

        def deactivate
          t = Template.find(params[:id])
          t.update!(active: false)
          json_success({ message: "Template deactivated" })
        end

        def activate
          t = Template.find(params[:id])
          t.update!(active: true)
          json_success({ message: "Template activated" })
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

        def set_default
          template = Template.find(params[:id])

          ActiveRecord::Base.transaction do
            Template
              .where(
                template_type: template.template_type,
                is_default: true
              )
              .where.not(id: template.id)
              .update_all(is_default: false)

            template.update!(is_default: true)
          end

          json_success(template_resp(template))
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
          { id: t.id, name: t.name.titleize, template_type: t.template_type, active: t.active, is_default: t.is_default }
        end
      end
    end
  end
end
