class CreateCrmFunnels < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_funnels do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    create_table :crm_funnel_stages do |t|
      t.references :crm_funnel, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :crm_funnel_stages, [:crm_funnel_id, :label_id], unique: true
    add_index :crm_funnel_stages, [:crm_funnel_id, :position]
  end
end
