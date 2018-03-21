module Ao
  class Installer
    class << self
      def call(api_key)
        script_path = File.expand_path(
          "../../appoptics-host-agent-installer.sh", __FILE__
        )
        system %(export APPOPTICS_INSTALL_ONLY=1)
        system %(bash #{script_path} --token #{api_key} -y)
      end
    end
  end
end
