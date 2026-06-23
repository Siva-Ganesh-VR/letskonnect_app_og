class CreateVisitorAnswers < ActiveRecord::Migration[7.2]
  def change
    create_table :visitor_answers do |t|
      t.references :visitor, type: :uuid, null: false, foreign_key: true

      t.string :question_key, null: false
      t.text :answer

      t.timestamps
    end
  end
end
