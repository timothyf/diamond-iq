class ApplicationCalendar
  DEFAULT_TIME_ZONE = "America/Detroit"

  def self.current_date(now: Time.current)
    now.in_time_zone(ENV.fetch("APP_TIME_ZONE", DEFAULT_TIME_ZONE)).to_date
  end
end
