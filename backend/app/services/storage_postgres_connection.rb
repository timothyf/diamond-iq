class StoragePostgresConnection
  POSTGRES_ENVIRONMENT_KEYS = {
    password: "PGPASSWORD",
    sslmode: "PGSSLMODE",
    sslcert: "PGSSLCERT",
    sslkey: "PGSSLKEY",
    sslrootcert: "PGSSLROOTCERT"
  }.freeze

  def initialize(db_config: ActiveRecord::Base.connection_db_config)
    @configuration = db_config.configuration_hash.symbolize_keys
  end

  def database
    configuration.fetch(:database).to_s
  end

  def arguments(database: self.database)
    [].tap do |arguments|
      arguments << "--host=#{configuration[:host]}" if configuration[:host].present?
      arguments << "--port=#{configuration[:port]}" if configuration[:port].present?
      arguments << "--username=#{configuration[:username]}" if configuration[:username].present?
      arguments << "--dbname=#{database}"
    end
  end

  def environment
    POSTGRES_ENVIRONMENT_KEYS.each_with_object({}) do |(configuration_key, environment_key), result|
      value = configuration[configuration_key]
      result[environment_key] = value.to_s if value.present?
    end
  end

  private

  attr_reader :configuration
end
