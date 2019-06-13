require "date"
require "erb"
require "fileutils"
require_relative "../scout/client"

class SnapConfig
  attr_reader :account_key, :agent_ruby_bin, :ruby_path, :plugin_directory, :agent_data_file

  def initialize
    @account_key = Scout.new.account_key

    scout_location = %x(find / -iname scout-client 2>/dev/null | head -1).chomp
    @agent_ruby_bin = scout_location + "/bin/scout"

    @ruby_path = %x(which ruby)
    @plugin_directory = Plugins::PLUGIN_PATH
    @agent_data_file = Scout::HISTORY_FILE
  end

  def reconfigure
    create_psm_config
    create_psm_task
    create_statsd_config
    create_statsd_bridge_config
  end

  def roles
    return @roles.gsub(",", " ") if @roles
    @api_roles.join(" ") if @api_roles
  end

  def environment
    @environment ||= ENV["RACK_ENV"] || "production"
  end

  def hostname
    @hostname ||= %x(hostname).chomp
  end

  def generated_time
    Time.now.to_s
  end

  private

  def create_psm_config
    template_path = "../../templates/psm.yaml.erb"
    template = render_template(template_path).result(binding)
    update_config_file(%(/opt/SolarWinds/Snap/etc/plugins.d/psm.yaml), template)
  end

  def create_psm_task
    template_path = "../../templates/task-psm.yaml.erb"
    template = render_template(template_path).result(binding)
    update_config_file(%(/opt/SolarWinds/Snap/etc/tasks.d/task-psm.yaml), template)
  end

  def create_statsd_config
    template_path = "../../templates/task-bridge-statsd.yaml.erb"
    template = render_template(template_path).result(binding)
    update_config_file(%(/opt/SolarWinds/Snap/etc/tasks.d/task-bridge-statsd.yaml), template)
  end

  def create_statsd_bridge_config
    template_path = "../../templates/statsd.yaml.erb"
    template = render_template(template_path).result(binding)
    update_config_file(%(/opt/SolarWinds/Snap/etc/plugins.d/statsd.yaml), template)
  end

  def update_config_file(path, template)
    system "[ -f #{path} ] && mv -f #{path} #{path}.bak"

    File.write(path, template)
    system "chown -R solarwinds:solarwinds #{path}"
  end

  def render_template(template_path)
    @erb_template = ERB.new(File.read(
      File.expand_path(template_path, __FILE__)))
  end

end
