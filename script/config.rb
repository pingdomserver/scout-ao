require 'erb'
require 'pry'

class Configuration
  def initialize(opts = {})
    opts.each do |k,v|
      instance_variable_set :"@#{k}", v
    end
    @erb_template = ERB.new(File.read(
      File.expand_path(
        "../../config/templates/config.yml.erb", __FILE__
    )))
  end

  def call
    puts @erb_template.result(binding)
  end

  attr_reader :account_key, :environment, :hostname, :roles
end
