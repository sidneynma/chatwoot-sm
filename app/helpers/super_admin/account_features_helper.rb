module SuperAdmin::AccountFeaturesHelper
  def self.account_features
    YAML.safe_load(Rails.root.join('config/features.yml').read).freeze
  end

  def self.account_premium_features
    account_features.filter { |feature| feature['premium'] }.pluck('name')
  end

  # Chatolhe modules catalog (separate from FlagShihTzu feature_flags).
  def self.chatolhe_modules_catalog
    @chatolhe_modules_catalog ||= YAML.safe_load(
      Rails.root.join('config/chatolhe_modules.yml').read
    ).freeze
  end

  def self.chatolhe_module_names
    chatolhe_modules_catalog.pluck('name')
  end

  def self.chatolhe_module_enabled?(account, name)
    name = name.to_s
    stored = account.custom_attributes&.dig('chatolhe_modules') || {}
    return ActiveModel::Type::Boolean.new.cast(stored[name]) if stored.key?(name)

    entry = chatolhe_modules_catalog.find { |mod| mod['name'] == name }
    ActiveModel::Type::Boolean.new.cast(entry&.fetch('default_enabled', false))
  end

  # Hash of module_name => enabled for API / sidebar.
  def self.chatolhe_modules_enabled_hash(account)
    chatolhe_module_names.index_with { |name| chatolhe_module_enabled?(account, name) }
  end

  # Returns [[name, display_name], enabled_boolean] pairs for Super Admin UI.
  def self.chatolhe_modules_for(account)
    chatolhe_modules_catalog.to_h do |mod|
      [[mod['name'], mod['display_name']], chatolhe_module_enabled?(account, mod['name'])]
    end
  end

  # Returns a hash mapping feature names to their display names
  def self.feature_display_names
    account_features.each_with_object({}) do |feature, hash|
      hash[feature['name']] = feature['display_name']
    end
  end

  def self.filter_internal_features(features)
    return features if ChatwootApp.chatwoot_cloud?

    internal_features = account_features.select { |f| f['chatwoot_internal'] }.pluck('name')
    features.except(*internal_features)
  end

  def self.filter_deprecated_features(features)
    deprecated_features = account_features.select { |f| f['deprecated'] }.pluck('name')
    features.except(*deprecated_features)
  end

  def self.sort_and_transform_features(features, display_names)
    features.sort_by { |key, _| display_names[key] || key }
            .to_h
            .transform_keys { |key| [key, display_names[key]] }
  end

  def self.partition_features(features)
    filtered = filter_internal_features(features)
    filtered = filter_deprecated_features(filtered)
    display_names = feature_display_names

    regular, premium = filtered.partition { |key, _value| account_premium_features.exclude?(key) }

    [
      sort_and_transform_features(regular, display_names),
      sort_and_transform_features(premium, display_names)
    ]
  end

  def self.filtered_features(features)
    regular, premium = partition_features(features)
    regular.merge(premium)
  end
end
