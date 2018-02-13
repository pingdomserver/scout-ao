require_relative './client'
require_relative './config'

class Runner
  class << self
    def run
      client_configuration = Client.gather_facts
      Configuration.new(client_configuration).call
    end
  end
end
