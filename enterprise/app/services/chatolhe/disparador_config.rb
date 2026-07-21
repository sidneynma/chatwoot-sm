# Reads Disparador InstallationConfig values (defaults match dashord-campanha stack).
class Chatolhe::DisparadorConfig
  DEFAULTS = {
    'DISPARADOR_DISPATCH_BATCH_SIZE' => 50,
    'DISPARADOR_META_CONCURRENCY' => 20,
    'DISPARADOR_SCHEDULER_ENABLED' => true,
    'DISPARADOR_SCHEDULER_INTERVAL_MS' => 60_000,
    'DISPARADOR_SCHEDULER_INITIAL_DELAY_MS' => 15_000,
    'DISPARADOR_SCHEDULER_BATCH_CAMPAIGNS' => 5,
    'DISPARADOR_MEDIA_PUBLIC_BASE_URL' => nil,
    'DISPARADOR_MEDIA_BUCKET' => 'imagemcampanha'
  }.freeze

  class << self
    def batch_size
      int_value('DISPARADOR_DISPATCH_BATCH_SIZE')
    end

    def meta_concurrency
      int_value('DISPARADOR_META_CONCURRENCY')
    end

    def scheduler_enabled?
      bool_value('DISPARADOR_SCHEDULER_ENABLED')
    end

    def scheduler_interval_ms
      int_value('DISPARADOR_SCHEDULER_INTERVAL_MS')
    end

    def scheduler_initial_delay_ms
      int_value('DISPARADOR_SCHEDULER_INITIAL_DELAY_MS')
    end

    def scheduler_batch_campaigns
      int_value('DISPARADOR_SCHEDULER_BATCH_CAMPAIGNS')
    end

    def media_public_base_url
      raw = InstallationConfig.find_by(name: 'DISPARADOR_MEDIA_PUBLIC_BASE_URL')&.value
      raw.presence || ENV['DISPARADOR_MEDIA_PUBLIC_BASE_URL'].presence ||
        DEFAULTS['DISPARADOR_MEDIA_PUBLIC_BASE_URL']
    end

    def media_bucket
      raw = InstallationConfig.find_by(name: 'DISPARADOR_MEDIA_BUCKET')&.value
      raw.presence || ENV['DISPARADOR_MEDIA_BUCKET'].presence ||
        DEFAULTS['DISPARADOR_MEDIA_BUCKET']
    end

    private

    def int_value(name)
      raw = InstallationConfig.find_by(name: name)&.value
      value = raw.presence || DEFAULTS[name]
      value.to_i
    end

    def bool_value(name)
      raw = InstallationConfig.find_by(name: name)&.value
      return DEFAULTS[name] if raw.nil?

      ActiveModel::Type::Boolean.new.cast(raw)
    end
  end
end
