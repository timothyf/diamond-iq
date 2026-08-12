module NineLensConfig
  def self.fetch(*keys)
    keys.reduce(Rails.application.config.x.ninelens) { |config, key| config.fetch(key) }
  end
end
