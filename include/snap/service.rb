class SnapService
	class << self
		def stop
			system "service swisnapd stop"
		end

		def start
			system "service swisnapd restart"
		end
	end
end
