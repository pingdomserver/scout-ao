require "erb"
require "fileutils"

class SnapConfig

	PSM_CONFIG_PATH = %(/opt/SolarWinds/Snap/etc/plugins.d/psm.yaml)
	PSM_TASK_PATH = %(/opt/SolarWinds/Snap/etc/tasks.d/task-psm.yaml)
	STATSD_CONFIG_PATH = %(/opt/SolarWinds/Snap/etc/tasks.d/task-bridge-statsd.yaml)
	STATSD_BRIDGE_CONFIG_PATH = %(/opt/SolarWinds/Snap/etc/plugins.d/statsd.yaml)

	attr_reader :account_key, :key_processes, :agent_ruby_bin, :ao_token

	def initialize(opts = {})
		opts.each do |k, v|
			instance_variable_set :"@#{k}", v
		end
		gem_location = %x(gem which scout | grep #{Runner::SCOUT_GEM_VERSION}).chomp
		@agent_ruby_bin = gem_location.split("/")[0..-3].join("/") + "/bin/scout"
	end

	def reconfigure(options)
		create_psm_config
		create_psm_task
		create_statsd_config
		create_statsd_bridge_config
	end

	# Fix scout-related permissions
	# (scout-client would be ran under solarwinds user/group)
	def fix_permissions
		system "usermod -a -G scoutd solarwinds"
		system "chmod -v g+rw /var/log/scout/scoutd.log"
		system "chmod -Rv g+w /var/lib/scoutd"
	end

	def roles
		return @roles.gsub(",", " ") if @roles
		@api_roles.join(" ") if @api_roles
	end

	def environment
		@environment || environment_from_api || "production"
	end

	def hostname
		@hostname || %x(hostname).chomp
	end

	private

		def create_psm_config
			template_path = "../../config/templates/psm.yaml.erb"
			template = erb_template(template_path).result(binding)
			write_file(PSM_CONFIG_PATH, template)
		end

		def create_psm_task
			template_path = "../../config/templates/task-psm.yaml.erb"
			template = erb_template(template_path).result(binding)
			write_file(PSM_TASK_PATH, template)
		end

		def create_statsd_config
			template_path = "../../config/templates/statsd-task.yaml.erb"
			template = erb_template(template_path).result(binding)
			write_file(STATSD_CONFIG_PATH, template)
		end

		def create_statsd_bridge_config
			template_path = "../../config/statsd-bridge.yaml"
			template = erb_template(template_path).result(binding)
			write_file(STATSD_BRIDGE_CONFIG_PATH, template)
		end

		def write_file(path, template)
			File.write(path, template)

			%x(chown -R solarwinds:solarwinds #{path})
		end

		def erb_template(template_path)
			@erb_template = ERB.new(File.read(
				File.expand_path(
					template_path, __FILE__
				)))
		end

		def environment_from_api
			client = ::Psm::ApiClient.new(account_key, hostname)
			response = client.make_request("/api/v2/account/clients/environment")

			response["name"]
		end
end
