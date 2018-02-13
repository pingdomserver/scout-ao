require_relative './client'
require_relative './config'
require_relative './plugin'

class Runner
  class << self
    def run
      client_configuration = Client.gather_facts
      Plugin::Downloader.new(client_configuration).call
      Configuration.new(client_configuration).call
    end
  end
end
