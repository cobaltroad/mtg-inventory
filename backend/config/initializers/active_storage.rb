Rails.application.config.active_storage.routes_prefix = "#{ENV['PUBLIC_API_PATH']}/rails/active_storage"
# TODO: Eventually scale by switching to redirect via S3 to eliminate DiskService
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy
