namespace :disparador do
  desc 'Import campaigns/recipients from Campaign Dashboard DB into Disparador'
  task import_from_dashboard: :environment do
    source_url = ENV.fetch('CAMPAIGN_DASHBOARD_DATABASE_URL') do
      abort 'Set CAMPAIGN_DASHBOARD_DATABASE_URL (e.g. postgres://user:pass@host:5432/campaign_dashboard_import)'
    end
    account_id = ENV.fetch('ACCOUNT_ID') { abort 'Set ACCOUNT_ID' }
    target_account_id = ENV['TARGET_ACCOUNT_ID']
    campaign_ids = ENV['CAMPAIGN_IDS'].to_s.split(',').map(&:strip).reject(&:blank?)
    dry_run = ENV['DRY_RUN'].present?

    puts "Source: #{source_url.sub(%r{://[^@]+@}, '://***@')}"
    puts "Account: #{account_id} → target #{target_account_id.presence || account_id}"
    puts "Campaign IDs: #{campaign_ids.presence || 'all'}"
    puts "Dry run: #{dry_run}"

    stats = Disparador::ImportFromDashboardService.new(
      source_url: source_url,
      account_id: account_id,
      target_account_id: target_account_id,
      campaign_ids: campaign_ids,
      dry_run: dry_run
    ).perform

    puts "Done: #{stats.inspect}"
  end
end
