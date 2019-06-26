require_relative "config"

class Snap
  SWISNAPD = "swisnapd"
  
  class << self
    def stop
      system "service #{SWISNAPD} stop"
    end

    def reconfigure
      SnapConfig.new.reconfigure
    end

    def start
      system "service #{SWISNAPD} restart"
    end
  end
end
