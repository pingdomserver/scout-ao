require "erb"
require "fileutils"
require_relative "../scout/client"

class SnapConfig
  attr_reader :account_key, :key_processes, :agent_ruby_bin, :ao_token

  def initialize(opts = {})
    opts.each do |k, v|
      instance_variable_set :"@#{k}", v
    end
    gem_location = %x(gem which scout | grep #{Runner::SCOUT_GEM_VERSION}).chomp
    @agent_ruby_bin = gem_location.split("/")[0..-3].join("/") + "/bin/scout"
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
    @environment || PSM || "production"
  end

  def hostname
    @hostname || %x(hostname).chomp
  end

  private

  def create_psm_config
    template_path = "../../templates/psm.yaml.erb"
    template = erb_template(template_path).result(binding)
    write_file(%(/opt/SolarWinds/Snap/etc/plugins.d/psm.yaml), template)
  end

  def create_psm_task
    template_path = "../../templates/task-psm.yaml.erb"
    template = erb_template(template_path).result(binding)
    write_file(%(/opt/SolarWinds/Snap/etc/tasks.d/task-psm.yaml), template)
  end

  def create_statsd_config
    template_path = "../../templates/statsd-task.yaml.erb"
    template = erb_template(template_path).result(binding)
    write_file(%(/opt/SolarWinds/Snap/etc/tasks.d/task-bridge-statsd.yaml), template)
  end

  def create_statsd_bridge_config
    template_path = "../../templates/statsd-bridge.yaml"
    template = erb_template(template_path).result(binding)
    write_file(%(/opt/SolarWinds/Snap/etc/plugins.d/statsd.yaml), template)
  end

  def write_file(path, template)
    unless File.exists?(path)
      File.write(path, template)
      system "chown -R solarwinds:solarwinds #{path}"
    end
  end

  def erb_template(template_path)
    @erb_template = ERB.new(File.read(
      File.expand_path(template_path, __FILE__)))
  end

end
