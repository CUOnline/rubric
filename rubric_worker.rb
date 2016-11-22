require './rubric_app'
require 'csv'

class RubricWorker
  @queue = 'rubric'

  def self.perform(account_id, email)
    # Collect data and generate CSV
  end
end
