require_relative "config"

class Snap
  class << self
    def stop
      system "service swisnapd stop"
    end

    def reconfigure
      SnapConfig.new.reconfigure
    end

    def start
      system "service swisnapd restart"
    end
  end
end
