require 'csv'

class Disparador::CampaignsExportService
  pattr_initialize [:campaigns!, :locale]

  HEADERS = [
    'Campanha',
    'Status',
    'Canal',
    'Inbox',
    'Disparo',
    'Destinatarios',
    'Enviadas',
    'Falhas',
    'Respostas',
    'Taxa resp. (%)'
  ].freeze

  def to_csv
    body = CSV.generate(encoding: 'UTF-8') do |csv|
      csv << HEADERS
      campaigns.find_each do |campaign|
        stats = campaign.recipient_stats
        sent = stats['sent'].to_i + stats['delivered'].to_i + stats['read'].to_i + stats['replied'].to_i
        replied = stats['replied'].to_i
        rate = sent.zero? ? 0 : ((replied.to_f / sent) * 100).round(1)
        dispatched = campaign.started_at || campaign.scheduled_at || campaign.created_at

        csv << [
          campaign.name,
          campaign.status,
          campaign.channel,
          campaign.inbox&.name,
          dispatched&.in_time_zone&.strftime('%d/%m/%Y %H:%M'),
          stats.values.sum,
          sent,
          stats['failed'].to_i,
          replied,
          rate
        ]
      end
    end
    "\uFEFF#{body}"
  end
end
