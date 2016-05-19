require 'rspec'
require 'resque_spec'

require_relative '../lib/3scale/backend.rb'
require_relative '../test/test_helpers/sequences.rb'

RSpec.configure do |config|
  config.before :suite do
    ThreeScale::Backend.configure do |app_config|
      app_config.redis.nodes = [
        "127.0.0.1:7379",
        "127.0.0.1:7380",
      ]

      app_config.cubert.host = 'http://localhost:8080'

      app_config.redshift.host = 'localhost'
      app_config.redshift.port = 5432
      app_config.redshift.dbname = 'test'
      app_config.redshift.user = 'postgres'
    end
  end

  config.mock_with :rspec

  config.before :each do
    ThreeScale::Backend::Storage.instance(true).flushdb
    ThreeScale::Backend::Memoizer.reset!
  end
end
