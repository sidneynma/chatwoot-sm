class CreateDisparadorCampaigns < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :disparador_campaigns do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :inbox, foreign_key: true
      t.uuid :uuid, null: false, default: 'gen_random_uuid()'
      t.string :name, null: false
      t.text :description
      t.string :channel, null: false, default: 'whatsapp'
      t.string :status, null: false, default: 'draft'
      t.text :message_template
      t.datetime :scheduled_at
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :archived_at
      t.integer :created_by_id
      t.string :created_by_email
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :disparador_campaigns, :uuid, unique: true
    add_index :disparador_campaigns, [:account_id, :status]
    add_index :disparador_campaigns, [:account_id, :archived_at]

    create_table :disparador_recipients do |t|
      t.references :disparador_campaign, null: false, foreign_key: true, index: true
      t.uuid :uuid, null: false, default: 'gen_random_uuid()'
      t.integer :contact_id
      t.integer :conversation_id
      t.string :name
      t.string :phone, limit: 50
      t.string :email
      t.string :status, null: false, default: 'pending'
      t.datetime :last_event_at
      t.datetime :scheduled_at
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :disparador_recipients, :uuid, unique: true
    add_index :disparador_recipients, [:disparador_campaign_id, :phone],
              unique: true,
              where: 'phone IS NOT NULL',
              name: 'index_disparador_recipients_on_campaign_and_phone'
    add_index :disparador_recipients, [:disparador_campaign_id, :status]
  end
end
