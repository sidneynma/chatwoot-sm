module Enterprise::SuperAdmin::AccountsController
  def create
    manually_managed = params[:account]&.delete(:manually_managed_features)

    super do |resource|
      if manually_managed.present?
        service = ::Internal::Accounts::InternalAttributesService.new(resource)
        service.manually_managed_features = manually_managed
      end
      persist_chatolhe_modules!(resource) if params[:enabled_features]
    end
  end

  def update
    # Handle manually managed features from form submission
    if params[:account] && params[:account][:manually_managed_features].present?
      # Update using the service - it will handle array conversion and validation
      service = ::Internal::Accounts::InternalAttributesService.new(requested_resource)
      service.manually_managed_features = params[:account][:manually_managed_features]

      # Remove the manually_managed_features from params to prevent ActiveModel::UnknownAttributeError
      params[:account].delete(:manually_managed_features)
    end

    # Same edit form as All features — assign Chatolhe modules; super persists the row
    assign_chatolhe_modules!(requested_resource) if params[:enabled_features]

    super
  end

  private

  def assign_chatolhe_modules!(account)
    submitted = params[:chatolhe_modules] || {}
    modules = SuperAdmin::AccountFeaturesHelper.chatolhe_module_names.index_with do |name|
      submitted.key?(name) || submitted.key?(name.to_sym)
    end

    account.custom_attributes = (account.custom_attributes || {}).merge('chatolhe_modules' => modules)
  end

  def persist_chatolhe_modules!(account)
    assign_chatolhe_modules!(account)
    account.save! if account.changed?
  end
end
