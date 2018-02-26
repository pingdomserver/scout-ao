require 'erb'
require 'pry'

class Configuration
  CONFIG_PATH = %(/opt/appoptics/etc/plugins.d/psm.yaml)

  def initialize(opts = {})
    opts.each do |k,v|
      instance_variable_set :"@#{k}", v
    end
    @erb_template = ERB.new(File.read(
      File.expand_path(
        "../../config/templates/psm.yaml.erb", __FILE__
    )))
  end

  def call
    File.write(CONFIG_PATH, @erb_template.result(binding))
  end

  attr_reader :account_key, :environment, :hostname, :roles, :key_processes
end
