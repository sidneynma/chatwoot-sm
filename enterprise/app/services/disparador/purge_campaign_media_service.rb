# Removes campaign media from MinIO when archiving, if no other campaign shares the URL.
class Disparador::PurgeCampaignMediaService
  pattr_initialize [:campaign!]

  def perform
    media_url = extract_media_url
    return if media_url.blank?
    return if shared_by_other_campaign?(media_url)

    key = Disparador::MediaUploadService.object_key_from_url(media_url)
    return if key.blank?
    return unless key.start_with?("#{campaign.account_id}/")

    Disparador::MediaUploadService.delete_object(key)
    clear_media_from_metadata!
  end

  private

  def extract_media_url
    meta = campaign.metadata || {}
    meta.dig('media', 'media_url').presence ||
      meta.dig('template', 'processed_params', 'header', 'media_url').presence
  end

  def shared_by_other_campaign?(media_url)
    DisparadorCampaign
      .where(account_id: campaign.account_id)
      .where.not(id: campaign.id)
      .where(
        "metadata->'media'->>'media_url' = :url OR " \
        "metadata->'template'->'processed_params'->'header'->>'media_url' = :url",
        url: media_url
      ).exists?
  end

  def clear_media_from_metadata!
    meta = (campaign.metadata || {}).deep_dup
    if meta.dig('media', 'media_url').present?
      meta['media'] = (meta['media'] || {}).merge('purged_at' => Time.current.iso8601, 'media_url' => nil)
    end
    header = meta.dig('template', 'processed_params', 'header')
    if header.is_a?(Hash) && header['media_url'].present?
      header = header.merge('purged_at' => Time.current.iso8601, 'media_url' => nil)
      meta['template'] ||= {}
      meta['template']['processed_params'] ||= {}
      meta['template']['processed_params']['header'] = header
    end
    campaign.update_columns(metadata: meta, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
