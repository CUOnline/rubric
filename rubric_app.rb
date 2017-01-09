require 'bundler/setup'
require 'wolf_core'
require './rubric_worker'

class RubricApp < WolfCore::App
  set :root, File.dirname(__FILE__)
  set :auth_paths, [/.*/]
  set :public_paths, [/lti_config/, /launch/]
  set :allowed_roles, ['AccountAdmin', 'TeacherEnrollment']
  set :logger, create_logger
  set :api_cache, ActiveSupport::Cache::RedisStore.new(
                    redis_options.merge({:expires_in => 60 * 60 * 48}))

  enable :exclude_js
  enable :exclude_css

  helpers do
    def error_message(session)
      if session['lti_email'].nil? || session['lti_email'].empty?
        'Email for sending report not found. Please update your Canvas contact information.'
      elsif session['lti_account_id'].nil?
        'No account ID provided. Please check LTI tool configuration.'
      else
        nil
      end
    end

    def account_name(account_id)
      query = 'SELECT name FROM account_dim WHERE canvas_id = ?'
      canvas_data(query, session['lti_account_id']).collect{|r| r['name']}.first
    end
  end

  before do
    headers 'X-Frame-Options' => "ALLOW-FROM #{settings.canvas_url}"
  end

  get '/' do
    error = error_message(session)
    flash.now[:danger] = error if error

    slim :index, :locals => {
      :lti_email => session['lti_email'],
      :lti_account_id => session['lti_account_id']
    }
  end

  post '/launch' do
    if valid_lti_request?(request, params)
      session['lti_account_id'] ||= params['custom_canvas_account_id']
      session['lti_email'] ||= params['lis_person_contact_email_primary']
      redirect mount_point
    else
      status 400
      flash.now[:danger] = "Invalid request. Please check LTI configuration"
      slim ''
    end
  end

  post '/generate-report' do
    error = error_message(session)
    if error
      flash[:danger] = error
    else
      Resque.enqueue(RubricWorker, session['lti_account_id'], session['lti_email'])
      flash[:success] = "Report is being generated and will be emailed when complete."
    end

    redirect mount_point
  end

  get '/lti_config' do
    headers 'Content-Type' => 'text/xml'
    slim :lti_config, :layout => false
  end
end
