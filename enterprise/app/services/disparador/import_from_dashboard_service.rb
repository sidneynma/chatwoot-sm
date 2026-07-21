# Imports campaigns/recipients from the external Campaign Dashboard DB
# into native Disparador tables (idempotent by legacy uuid).
#
# Usage:
#   CAMPAIGN_DASHBOARD_DATABASE_URL=postgres://postgres:pass@127.0.0.1:5432/campaign_dashboard_import \
#   ACCOUNT_ID=10 \
#   bundle exec rake disparador:import_from_dashboard
#
# Options via ENV:
#   ACCOUNT_ID                 (required) source + target account id
#   TARGET_ACCOUNT_ID          (optional) remap into another Chatwoot account
#   CAMPAIGN_DASHBOARD_DATABASE_URL (required) source postgres URL
#   DRY_RUN=1                  print plan only
#   CAMPAIGN_IDS=25,27,34      optional filter
class Disparador::ImportFromDashboardService
  BATCH_SIZE = 500

  pattr_initialize [:source_url!, :account_id!, :target_account_id, :campaign_ids, :dry_run]

  def perform
    @target_account_id = (target_account_id.presence || account_id).to_i
    @account_id = account_id.to_i
    @dry_run = ActiveModel::Type::Boolean.new.cast(dry_run)
    @stats = { campaigns: 0, recipients: 0, skipped_campaigns: 0, skipped_recipients: 0 }

    validate!
    source_campaigns = fetch_campaigns
    Rails.logger.info("[Disparador::Import] account=#{@account_id} target=#{@target_account_id} campaigns=#{source_campaigns.size} dry_run=#{@dry_run}")

    source_campaigns.each do |row|
      import_campaign!(row)
    end

    @stats
  ensure
    close_source!
  end

  private

  def validate!
    raise ArgumentError, 'CAMPAIGN_DASHBOARD_DATABASE_URL is required' if source_url.blank?
    raise ArgumentError, 'ACCOUNT_ID is required' if @account_id <= 0
    raise ArgumentError, "Account #{@target_account_id} not found" unless Account.exists?(@target_account_id)
  end

  def source
    @source ||= begin
      require 'pg' unless defined?(PG)
    PG.connect(source_url)
    end
  end

  def close_source!
    @source&.close
  rescue StandardError
    nil
  end

  def fetch_campaigns
    sql = <<~SQL.squish
      SELECT id, uuid, account_id, inbox_id, name, description, channel, status,
             message_template, scheduled_at, started_at, completed_at, archived_at,
             created_by_id, created_by_email, metadata, created_at, updated_at
      FROM campaigns
      WHERE account_id = $1
    SQL
    params = [@account_id]
    if campaign_ids.present?
      ids = Array(campaign_ids).map(&:to_i).reject(&:zero?)
      if ids.any?
        sql += " AND id = ANY($2::bigint[])"
        params << "{#{ids.join(',')}}"
      end
    end
    sql += ' ORDER BY id'

    source.exec_params(sql, params).to_a
  end

  def fetch_recipients(legacy_campaign_id)
    source.exec_params(
      <<~SQL.squish,
        SELECT id, uuid, campaign_id, contact_id, conversation_id, name, phone, email,
               status, last_event_at, scheduled_at, error_message, metadata, created_at, updated_at
        FROM campaign_recipients
        WHERE campaign_id = $1
        ORDER BY id
      SQL
      [legacy_campaign_id]
    ).to_a
  end

  def import_campaign!(row)
    uuid = row['uuid']
    existing = DisparadorCampaign.find_by(uuid: uuid) ||
               DisparadorCampaign.where(account_id: @target_account_id)
                                 .where("metadata->>'legacy_uuid' = ?", uuid)
                                 .first

    if existing
      @stats[:skipped_campaigns] += 1
      Rails.logger.info("[Disparador::Import] skip campaign uuid=#{uuid} already imported id=#{existing.id}")
      import_recipients!(existing, row['id'])
      return
    end

    metadata = parse_jsonb(row['metadata']).merge(
      'legacy_source' => 'campaign_dashboard',
      'legacy_campaign_id' => row['id'].to_i,
      'legacy_uuid' => uuid,
      'imported_at' => Time.current.iso8601
    )

    attrs = {
      account_id: @target_account_id,
      inbox_id: row['inbox_id'].presence&.to_i,
      uuid: uuid,
      name: row['name'],
      description: row['description'],
      channel: normalize_channel(row['channel']),
      status: row['status'].presence || 'completed',
      message_template: row['message_template'],
      scheduled_at: row['scheduled_at'],
      started_at: row['started_at'],
      completed_at: row['completed_at'],
      archived_at: row['archived_at'],
      created_by_id: row['created_by_id'].presence&.to_i,
      created_by_email: row['created_by_email'],
      metadata: metadata,
      created_at: row['created_at'],
      updated_at: row['updated_at']
    }

    if @dry_run
      recipient_count = source.exec_params(
        'SELECT COUNT(*) AS c FROM campaign_recipients WHERE campaign_id = $1',
        [row['id']]
      ).first['c'].to_i
      Rails.logger.info("[Disparador::Import] DRY campaign=#{row['name']} recipients=#{recipient_count}")
      @stats[:campaigns] += 1
      @stats[:recipients] += recipient_count
      return
    end

    campaign = DisparadorCampaign.create!(attrs)
    @stats[:campaigns] += 1
    Rails.logger.info("[Disparador::Import] campaign #{campaign.id} <= legacy #{row['id']} (#{campaign.name})")
    import_recipients!(campaign, row['id'])
  end

  def import_recipients!(campaign, legacy_campaign_id)
    rows = fetch_recipients(legacy_campaign_id)
    rows.each_slice(BATCH_SIZE) do |batch|
      batch.each { |row| import_recipient!(campaign, row) }
    end
  end

  def import_recipient!(campaign, row)
    uuid = row['uuid']
    if campaign.disparador_recipients.exists?(uuid: uuid) ||
       campaign.disparador_recipients.where("metadata->>'legacy_uuid' = ?", uuid).exists?
      @stats[:skipped_recipients] += 1
      return
    end

    phone = row['phone'].to_s.gsub(/\D/, '').presence
    if phone.present? && campaign.disparador_recipients.exists?(phone: phone)
      # Keep legacy row even if phone collides: append suffix in metadata-only path by skipping unique phone
      # Prefer skip to avoid breaking unique index.
      @stats[:skipped_recipients] += 1
      Rails.logger.warn("[Disparador::Import] skip recipient phone=#{phone} duplicate in campaign=#{campaign.id}")
      return
    end

    metadata = parse_jsonb(row['metadata']).merge(
      'legacy_source' => 'campaign_dashboard',
      'legacy_recipient_id' => row['id'].to_i,
      'legacy_uuid' => uuid,
      'imported_at' => Time.current.iso8601
    )

    return if @dry_run

    campaign.disparador_recipients.create!(
      uuid: uuid,
      contact_id: row['contact_id'].presence&.to_i,
      conversation_id: row['conversation_id'].presence&.to_i,
      name: row['name'],
      phone: phone,
      email: row['email'],
      status: normalize_recipient_status(row['status']),
      last_event_at: row['last_event_at'],
      scheduled_at: row['scheduled_at'],
      error_message: row['error_message'],
      metadata: metadata,
      created_at: row['created_at'],
      updated_at: row['updated_at']
    )
    @stats[:recipients] += 1
  end

  def parse_jsonb(value)
    case value
    when Hash then value
    when String then JSON.parse(value)
    else {}
    end
  rescue JSON::ParserError
    {}
  end

  def normalize_channel(channel)
    ch = channel.to_s.downcase
    return 'evolution' if ch == 'evolution'
    return 'whatsapp' if ch.blank? || ch == 'meta'

    ch
  end

  def normalize_recipient_status(status)
    st = status.to_s.downcase
    return st if DisparadorRecipient::STATUSES.include?(st)

    'failed'
  end
end
