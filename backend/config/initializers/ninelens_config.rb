config = begin
  Rails.application.config_for(:ninelens)
rescue RuntimeError
  Rails.application.config_for(:diamond_iq)
end.deep_symbolize_keys.freeze

Rails.application.config.x.ninelens = config
Rails.application.config.x.diamond_iq = config
