module DiamondIqConfig
  def self.fetch(*keys)
    keys.reduce(Rails.application.config.x.diamond_iq) { |config, key| config.fetch(key) }
  end
end
