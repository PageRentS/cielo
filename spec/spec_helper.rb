require 'json'
require 'yaml'
require 'cielo'
require 'fakeweb'
require 'watir-webdriver'

FakeWeb.allow_net_connect = false

module Helper
  @secrets
  def self.secrets
    @secrets = YAML.load_file('./spec/secrets.yml') if @secrets.nil?
    @secrets
  end
end
