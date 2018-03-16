module Ao
  class Installer
    PLUGIN_PATH = %(/opt/appoptics/bin/snap-plugin-collector-psm)
    class << self
      def call(api_key, options = {})
        script_path = File.expand_path(
          "../../appoptics-host-agent-installer.sh", __FILE__
        )
        system %(export APPOPTICS_INSTALL_ONLY=1)
        system %(bash #{script_path} --token #{api_key} -y)

        copy_psm_binary if options.fetch(:copy_agent, nil)
      end

      def copy_psm_binary
        binary_path = File.expand_path(
          "../../../package/snap-plugin-collector-psm", __FILE__
        )
        FileUtils.cp binary_path, PLUGIN_PATH
      end
    end
    private_class_method :copy_psm_binary
  end
end
