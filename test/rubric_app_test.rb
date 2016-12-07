require_relative './test_helper'

class RubricAppTest < Minitest::Test
  def test_get_lti_config
    get '/lti_config'
    assert_equal 200, last_response.status
  end

  def test_get
    login
    canvas_url = 'https://test.instructure.com'
    app.settings.stubs(:canvas_url).returns(canvas_url)

    get '/'
    assert_equal 200, last_response.status
    assert_equal "ALLOW-FROM #{canvas_url}", last_response.headers['X-Frame-Options']
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

  def test_post_launch
    account_id = '10'
    email = 'test@example.com'
    app.any_instance.stubs(:valid_lti_request?).returns(true)
    login

    post '/launch', {'custom_canvas_account_id' => account_id, 'lis_person_contact_email_primary' => email}
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal account_id, last_request.env['rack.session']['lti_account_id']
    assert_equal email, last_request.env['rack.session']['lti_email']
    assert_equal '/', last_request.path
  end

  def test_post_launch_invalid_lti_request
    canvas_url = 'https://test.instructure.com'
    app.settings.stubs(:canvas_url).returns(canvas_url)
    app.any_instance.expects(:valid_lti_request?).returns(false)
    login

    post '/launch'
    assert_equal 400, last_response.status
    assert_match /Invalid request/, last_response.body
    assert_equal "ALLOW-FROM #{canvas_url}", last_response.headers['X-Frame-Options']
  end

  def test_post_generate_report
    account_id = '10'
    email = 'test@example.com'
    login({'lti_account_id' => account_id, 'lti_email' => email})
    Resque.expects(:enqueue).with(RubricWorker, account_id, email)

    post '/generate-report'
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal '/', last_request.path
    assert_match /Report is being generated/, last_response.body
  end

  def test_post_generate_missing_email
    account_id = '10'
    login({'lti_account_id' => account_id})
    Resque.expects(:enqueue).never

    post '/generate-report'
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal '/', last_request.path
    assert_match /Email for sending report not found/, last_response.body
  end

  def test_post_generate_missing_account_id
    login({'lti_email' => 'test@example.com'})
    Resque.expects(:enqueue).never

    post '/generate-report'
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal '/', last_request.path
    assert_match /No account ID provided/, last_response.body
  end

  def test_post_generate_report_unauthenticated
    post '/generate-report'
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal '/canvas-auth-login', last_request.path
  end

  def test_post_generate_report_unauthorized
    login({'user_roles' => ['StudentEnrollment']})

    post '/generate-report'
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal '/unauthorized', last_request.path
  end
end
