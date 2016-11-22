require 'bundler/setup'
require 'wolf_core'
require './rubric_worker'

class RubricApp < WolfCore::App
  set :root, File.dirname(__FILE__)
  set :auth_paths, [/.*/]
  set :public_paths, [/lti_config/]

  get '/' do
    'Hello'
  end

  post '/' do
    Resque.enqueue(RubricWorker, params['custom_canvas_account_id'].to_i, session['user_email'])
  end

  get '/lti_config' do
    headers 'Content-Type' => 'text/xml'
    slim :lti_config, :layout => false
  end
end
