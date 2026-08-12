config = begin
  Rails.application.config_for(:ninelens)
rescue RuntimeError
  Rails.application.config_for(:ninelens, env: Rails.env)
end.deep_symbolize_keys.freeze

Rails.application.config.x.ninelens = config
Rails.application.config.x.ninelens = config
  