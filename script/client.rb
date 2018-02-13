require 'yaml'

class Client
  def self.gather_facts
    new.call
  end

  def initialize
    @hostname = `hostname`.chomp

    self
  end

  def call
    unless scout_configuration["hostname"]
      scout_configuration.merge!({ hostname: @hostname })
    end
    scout_configuration
  end

  private

  attr_reader :hostname

  def account_key
    scout_configuration["account_key"]
  end

  def config_file
    %(/etc/scout/scoutd.yml)
  end

  def scout_configuration
    @scout_configuration ||= YAML.load(File.read(config_file))
  end
end
