require "date"
require "erb"
require "fileutils"
require_relative "../scout/client"

class SnapConfig
  INSTALL_PATH = "/opt/SolarWinds/Snap"
  PLUGIN_PATH = "#{INSTALL_PATH}/bin/psm"

  attr_reader :account_key, :agent_ruby_bin, :ruby_path, :plugin_directory, :agent_data_file, :environment, :hostname, :roles

  def initialize
    scout = Scout.new
    @account_key = scout.account_key
    @environment = scout.environment
    @hostname = scout.hostname
    @roles = scout.roles.join(" ")

    scout_location = %x(find / -iname scout-client 2>/dev/null | head -1).chomp
    @agent_ruby_bin = scout_location + "/bin/scout"

    @ruby_path = %x(which ruby)
    @plugin_directory = PLUGIN_PATH
    @agent_data_file = Scout::HISTORY_FILE
  end

  def reconfigure
    [
      { name: "psm", location: "plugins.d" },
      { name: "task-psm", location: "tasks.d" },
      { name: "statsd", location: "plugins.d" },
      { name: "task-bridge-statsd", location: "tasks.d" },
    ].each do |t|
      render_config(t[:name], t[:location])
    end
  end

  def generated_time
    Time.now.to_s
  end

  private

  def render_config(name, location)
    template_path = "../../../templates/#{name}.yaml.erb"
    template = render_template(template_path).result(binding)
    update_config_file("#{INSTALL_PATH}/etc/#{location}/#{name}.yaml", template)
  end

  def update_config_file(path, template)
    system "[ -f #{path} ] && mv -f #{path} #{path}.bak"

    File.write(path, template)
    system "chown -R solarwinds:solarwinds #{path}"
  end

  def render_template(template_path)
    @erb_template = ERB.new(File.read(File.expand_path(template_path, __FILE__)))
  end

end
