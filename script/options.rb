require 'optparse'

class Options
  def self.parse(args)
    opts = {}

    parser = OptionParser.new do |o|
      o.on("--no-plugins") do |p|
        opts[:skip_plugins] = true
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
