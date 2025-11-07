class CreateWorkItems < ActiveRecord::Migration[8.1]
  def change
    create_table :work_items do |t|
      t.string :type, null: false
      t.string :title, null: false
      t.text :description
      t.string :status, default: "pending", null: false
      t.integer :github_issue_number
      t.integer :priority, default: 0

      t.timestamps
    end

    add_index :work_items, :type
    add_index :work_items, :status
    add_index :work_items, :github_issue_number, unique: true, where: "github_issue_number IS NOT NULL"
  end
end
