require_relative "client"

require "fileutils"

class Plugins < Struct.new(:name, :code, :config)
  PLUGIN_PATH = "/opt/SolarWinds/Snap/bin/psm"

  class Downloader
    def initialize(account_key, hostname)
      @account_key = account_key
      @hostname = hostname
    end

    def call
      ensure_directory_exists

      plugins = PSMClient.new(account_key, hostname).plugins
      plugins.each do |p|
        opts = (p["meta"]["options"] if p["meta"]) || {}
        cfg = Configuration.new(p["id"], p["name"], opts)
        name = "#{normalize_plugin_name(p['file_name'])}"
        plugin = Plugins.new(name, p["code"], cfg)
        plugin.save
      end
    end

    private

    attr_reader :account_key, :hostname

    def ensure_directory_exists
      unless File.exists?(PLUGIN_PATH)
        FileUtils.mkdir_p(PLUGIN_PATH)
      end
    end

    def normalize_plugin_name(name)
      name.downcase.gsub(/\W/, " ").split.join(" ").gsub(/\s/, "_")
    end
  end

  class Configuration < Struct.new(:id, :name, :opts)
    def to_yaml
      options = opts || {}
      options = options.inject({}) do |m, (k, v)|
        m[k] = v["value"] || v["default"]
        m
      end
      options.merge!({ id: id, name: name })
      options.to_yaml
    end
  end

  def save
    %w(save_ruby_code save_configuraton).each do |m|
      method(m).call
    end

    chown_plugin_path
  end

  private

  def save_ruby_code
    save_file("#{name}.rb", code)
  end

  def save_configuraton
    save_file("#{name}.yml", config.to_yaml)
  end

  def save_file(name, content)
    File.write("#{PLUGIN_PATH}/#{name}", content)
  end

  def chown_plugin_path
    %x(chown -R solarwinds:solarwinds #{PLUGIN_PATH})
  end
end
