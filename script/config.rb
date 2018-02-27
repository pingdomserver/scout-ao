require 'erb'
require 'pry'
require 'fileutils'

class Configuration
  PSM_CONFIG_PATH = %(/opt/appoptics/etc/plugins.d/psm.yaml)
  STATSD_CONFIG_PATH = %(/opt/appoptics/etc/tasks.d/task-bridge-statsd.yaml)
  STATSD_BRIDGE_CONFIG_PATH = %(/opt/appoptics/etc/plugins.d/statsd.yaml)

  def initialize(opts = {})
    opts.each do |k,v|
      instance_variable_set :"@#{k}", v
    end
    @agent_ruby_bin = %x(gem which scout | grep #{Runner::SCOUT_GEM_VERSION}).chomp
  end

  def call
    create_psm_config
    create_statsd_config
    create_statsd_bridge_config
  end

  attr_reader :account_key, :environment, :hostname, :roles, :key_processes,
    :agent_ruby_bin

  private

  def create_psm_config
    File.write(PSM_CONFIG_PATH, erb_template(
      "../../config/templates/psm.yaml.erb"
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

  def erb_template(template_path)
    @erb_template = ERB.new(File.read(
      File.expand_path(
        template_path, __FILE__
    )))
  end
end
