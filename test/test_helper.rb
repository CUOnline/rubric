require_relative '../rubric_app'

require 'minitest/autorun'
require 'minitest/rg'
require 'mocha/mini_test'
require 'rack/test'
require 'webmock/minitest'

# Turn on SSL for all requests
class Rack::Test::Session
  def default_env
    { 'rack.test' => true,
      'REMOTE_ADDR' => '127.0.0.1',
      'HTTPS' => 'on'
    }.merge(@env).merge(headers_for_env)
  end
end

class Minitest::Test

  include Rack::Test::Methods

  def app
    RubricApp
  end

  def login(session_params = {})
    defaults = {
      'user_id' => '123',
      'user_roles' => ['AccountAdmin'],
      'user_email' => 'test@example.com'
    }

    env 'rack.session', defaults.merge(session_params)
  end

  def setup
    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: true)
    Mail::Message.any_instance.stubs(:deliver!)
    app.set :api_cache, false
    app.any_instance.stubs(:account_name).returns('test')
  end
end
