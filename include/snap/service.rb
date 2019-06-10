class SnapService
	class << self
		def stop
			system "service swisnapd stop"
		end

		def start
			system "service appoptics-snapteld restart"
		end
	end
end
