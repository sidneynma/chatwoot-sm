# Uploads campaign media to a dedicated MinIO/S3 bucket and returns a public HTTPS URL.
# Uses the same STORAGE_* credentials as ActiveStorage s3_compatible; bucket is separate.
class Disparador::MediaUploadService
  ALLOWED_MIME = {
    'image/jpeg' => { ext: '.jpg', media_type: 'image' },
    'image/png' => { ext: '.png', media_type: 'image' },
    'image/webp' => { ext: '.webp', media_type: 'image' },
    'video/mp4' => { ext: '.mp4', media_type: 'video' },
    'video/3gpp' => { ext: '.3gp', media_type: 'video' },
    'application/pdf' => { ext: '.pdf', media_type: 'document' }
  }.freeze

  MAX_BYTES = 5.megabytes

  class Error < StandardError; end

  pattr_initialize [:account!, :file!]

  def perform
    validate!
    key = object_key
    file.tempfile.rewind
    self.class.client.put_object(
      bucket: self.class.bucket_name,
      key: key,
      body: file.tempfile,
      content_type: content_type
    )

    url = public_url_for(key)
    {
      url: url,
      media_url: url,
      media_type: mime_info[:media_type],
      filename: File.basename(key),
      original_filename: sanitize_filename(file.original_filename),
      media_name: mime_info[:media_type] == 'document' ? sanitize_filename(file.original_filename) : nil,
      size: file.size,
      mime_type: content_type,
      storage_key: key
    }
  end

  class << self
    def delete_object(key)
      return if key.blank?

      client.delete_object(bucket: bucket_name, key: key)
    rescue StandardError => e
      Rails.logger.warn("[Disparador] media delete failed key=#{key}: #{e.message}")
    end

    def object_key_from_url(media_url)
      base = Chatolhe::DisparadorConfig.media_public_base_url.to_s.sub(%r{/+$}, '')
      return if base.blank? || media_url.blank?
      return unless media_url.start_with?("#{base}/")

      key = media_url.delete_prefix("#{base}/").sub(%r{\A/+}, '')
      return if key.blank? || key.include?('..')

      key
    end

    def client
      Aws::S3::Client.new(
        access_key_id: ENV.fetch('STORAGE_ACCESS_KEY_ID', ENV.fetch('AWS_ACCESS_KEY_ID', '')),
        secret_access_key: ENV.fetch('STORAGE_SECRET_ACCESS_KEY', ENV.fetch('AWS_SECRET_ACCESS_KEY', '')),
        region: ENV.fetch('STORAGE_REGION', ENV.fetch('AWS_REGION', 'us-east-1')),
        endpoint: ENV['STORAGE_ENDPOINT'].presence,
        force_path_style: ActiveModel::Type::Boolean.new.cast(ENV.fetch('STORAGE_FORCE_PATH_STYLE', true))
      )
    end

    def bucket_name
      Chatolhe::DisparadorConfig.media_bucket
    end
  end

  private

  def validate!
    raise Error, 'Upload unavailable: configure DISPARADOR_MEDIA_PUBLIC_BASE_URL' if public_base.blank?
    raise Error, 'File is required' if file.blank?
    raise Error, 'Unsupported file type. Use JPEG, PNG, WebP, MP4 or PDF.' if mime_info.blank?
    raise Error, 'File exceeds 5MB limit' if file.size.to_i > MAX_BYTES
  end

  def content_type
    @content_type ||= file.content_type.to_s
  end

  def mime_info
    @mime_info ||= ALLOWED_MIME[content_type]
  end

  def object_key
    "#{account.id}/#{SecureRandom.uuid}#{mime_info[:ext]}"
  end

  def public_url_for(key)
    "#{public_base}/#{key}"
  end

  def public_base
    Chatolhe::DisparadorConfig.media_public_base_url.to_s.sub(%r{/+$}, '')
  end

  def sanitize_filename(name)
    base = File.basename(name.to_s.presence || 'arquivo')
    base.gsub(/[^\w.\- ()áàâãéêíóôõúüçÁÀÂÃÉÊÍÓÔÕÚÜÇ]/i, '_').slice(0, 240)
  end
end
