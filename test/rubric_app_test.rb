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

class RubricAppTest < Minitest::Test

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
    app.set :api_cache, false

  end

  def test_get
    login
    get '/'
    assert_equal 200, last_response.status
  end

  def test_get_lti_config
    get '/lti_config'
    assert_equal 200, last_response.status
  end

  def test_get_unauthenticated
    get '/'
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal '/canvas-auth-login', last_request.path
  end

  def test_get_unauthorized
    login({'user_roles' => ['StudentEnrollment']})
    get '/'
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal '/unauthorized', last_request.path
  end

  def test_post
    login
    account_id = 10
    Resque.expects(:enqueue).with(RubricWorker, account_id, 'test@example.com')
    post '/', {'custom_canvas_account_id' => account_id}
    assert_equal 200, last_response.status
  end

  def test_post_unauthenticated
    post '/'
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal '/canvas-auth-login', last_request.path
  end

  def test_post_unauthorized
    login({'user_roles' => ['StudentEnrollment']})
    post '/'
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal '/unauthorized', last_request.path
  end
end
