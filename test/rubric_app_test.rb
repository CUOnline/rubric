require_relative './test_helper'

class RubricAppTest < Minitest::Test
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
