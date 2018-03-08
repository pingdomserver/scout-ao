require 'erb'
require 'fileutils'

class Configuration
  PSM_CONFIG_PATH = %(/opt/appoptics/etc/plugins.d/psm.yaml)
  PSM_TASK_PATH = %(/opt/appoptics/etc/tasks.d/task-aopsm.yaml)
  STATSD_CONFIG_PATH = %(/opt/appoptics/etc/tasks.d/task-bridge-statsd.yaml)
  STATSD_BRIDGE_CONFIG_PATH = %(/opt/appoptics/etc/plugins.d/statsd.yaml)
  AO_AGENT_CONFIGURATION_PATH = %(/opt/appoptics/etc/config.yaml)

  def initialize(opts = {})
    opts.each do |k,v|
      instance_variable_set :"@#{k}", v
    end
    gem_location = %x(gem which scout | grep #{Runner::SCOUT_GEM_VERSION}).chomp
    @agent_ruby_bin = gem_location.split('/')[0..-3].join('/') + "/bin/scout"
  end

  def call
    create_psm_config
    create_psm_task
    create_statsd_config
    create_statsd_bridge_config
    update_ao_agent_configuration
  end

  attr_reader :account_key, :environment, :hostname, :key_processes,
    :agent_ruby_bin, :ao_token

  def roles
    @roles.gsub(',', ' ') if @roles
  end

  private

  def create_psm_config
    File.write(PSM_CONFIG_PATH, erb_template(
      "../../config/templates/psm.yaml.erb"
    ).result(binding))
  end

  def create_psm_task
    File.write(PSM_TASK_PATH, erb_template(
      "../../config/templates/task-aopsm.yaml.erb"
    ).result(binding))
  end

  def create_statsd_config
    File.write(STATSD_CONFIG_PATH, erb_template(
      "../../config/templates/statsd-task.yaml.erb"
    ).result(binding))
  end

  def create_statsd_bridge_config
    FileUtils.cp File.expand_path("../../config/statsd-bridge.yaml", __FILE__),
      STATSD_BRIDGE_CONFIG_PATH
  end

  def update_ao_agent_configuration
    File.write(AO_AGENT_CONFIGURATION_PATH, erb_template(
      "../../config/templates/ao_config.yaml.erb"
    ).result(binding))
  end

  def erb_template(template_path)
    @erb_template = ERB.new(File.read(
      File.expand_path(
        template_path, __FILE__
    )))
  end
end
