require 'optparse'

class Options
  def self.parse(args)
    opts = {}

    parser = OptionParser.new do |o|
      o.on("--no-plugin") do |p|
        opts[:skip_plugin] = true
      end

      o.on("--no-agent") do |a|
        opts[:skip_agent] = true
      end

      o.on("--no-config") do |c|
        opts[:skip_config] = true
      end

      o.on("--no-gems") do |g|
        opts[:skip_gems] = true
      end
    end
    parser.parse!(args)

    opts
  end
end
