json.id campaign.id
json.uuid campaign.uuid
json.account_id campaign.account_id
json.inbox_id campaign.inbox_id
json.inbox_name campaign.inbox&.name
json.name campaign.name
json.description campaign.description
json.channel campaign.channel
json.status campaign.status
json.message_template campaign.message_template
json.scheduled_at campaign.scheduled_at
json.started_at campaign.started_at
json.completed_at campaign.completed_at
json.archived_at campaign.archived_at
json.created_by_id campaign.created_by_id
json.created_by_email campaign.created_by_email
json.metadata campaign.metadata
json.dispatch_mode campaign.metadata&.dig('dispatch_mode')
json.template_name campaign.metadata&.dig('template', 'name')
json.created_at campaign.created_at
json.updated_at campaign.updated_at

stats = campaign.recipient_stats
sent = stats['sent'].to_i + stats['delivered'].to_i + stats['read'].to_i + stats['replied'].to_i
json.total_recipients stats.values.sum
json.pending_count stats['pending'].to_i
json.queued_count stats['queued'].to_i
json.sent_count sent
json.delivered_count stats['delivered'].to_i
json.read_count stats['read'].to_i
json.replied_count stats['replied'].to_i
json.failed_count stats['failed'].to_i
json.reply_rate(sent.zero? ? 0 : ((stats['replied'].to_i.to_f / sent) * 100).round(1))
