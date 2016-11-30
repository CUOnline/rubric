require 'bundler/setup'
require 'wolf_core'
require './rubric_worker'

class RubricApp < WolfCore::App
  set :root, File.dirname(__FILE__)
  set :auth_paths, [/.*/]
  set :public_paths, [/lti_config/]

  before do
    headers 'X-Frame-Options' => "ALLOW-FROM #{settings.canvas_url}"
  end

  get '/' do
    call env.merge('REQUEST_METHOD' => 'POST')
  end

  post '/' do
    email = session['user_email'] || params['lis_person_contact_email_primary']
    if email.nil? || email.empty?
      status 400
      flash.now[:danger] = 'Email for sending report not found. Please update your Canvas contact information.'
    else
      Resque.enqueue(RubricWorker, params['custom_canvas_account_id'].to_i, email)
      flash.now[:success] = "Report is being generated and will be sent to #{email} when finished."
    end

    # Explicitly render nothing to get the layout
    slim ''
  end

  get '/lti_config' do
    headers 'Content-Type' => 'text/xml'
    slim :lti_config, :layout => false
  end
end
