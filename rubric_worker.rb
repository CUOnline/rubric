require './rubric_app'
require 'csv'

class RubricWorker
  @queue = 'rubric'

  def self.perform(account_id, email)
    CSV.open('./out.csv', 'wb') do |csv|
      csv << self.csv_headers
      self.rubric_data_rows.map{ |row| csv << row }
    end
  end

  def self.csv_headers
    [
      'Course ID',
      'Course Name',
      'Term',
      'Assigment Name',
      'Assigment ID',
      'Rubric Name',
      'Rubric ID'
    ]
  end

  def self.rubric_data_rows(account_id)
    rows = []
    rubrics = self.account_rubric_ids(account_id)

    self.account_courses(account_id).each do |course|
      next if course['canvas_id'].nil?
      self.course_assignments(course['canvas_id']).each do |assignment|
        new_row = self.build_row(course, assignment, rubrics)
        rows << new_row unless new_row.nil?
      end
    end

    rows
  end

  def self.build_row(course, assignment, account_rubric_ids)
    if assignment['rubric_id'] && account_rubric_ids.include?(assignment['rubric_id'])
      [
        course['canvas_id'],
        course['name'],
        course['term'],
        assignment['assignment_title'],
        assignment['assignment_id'],
        assignment['rubric_title'],
        assignment['rubric_id']
      ]
    end
  end

  def self.account_rubric_ids(account_id)
    rubric_ids = []
    next_page = "accounts/#{account_id}/rubrics?per_page=100"
#   Disable pagination unitil it's fixed https://github.com/instructure/canvas-lms/pull/952
#   while next_page
      response = RubricApp.canvas_api.get(next_page)
      rubric_ids << response.body.collect{|rubric| rubric['id']}
#     next_page = RubricApp.parse_pages(response.headers[:link])["next"]
#   end
    rubric_ids.flatten
  end

  def self.account_courses(account_id)
    query_string =
      "SELECT course_dim.canvas_id, course_dim.name as name, enrollment_term_dim.name as term "\
      "FROM course_dim join enrollment_term_dim "\
        "ON course_dim.enrollment_term_id = enrollment_term_dim.id "\
      "WHERE account_id=? and course_dim.canvas_id = '346762' limit 1000;"

    RubricApp.canvas_data(query_string, RubricApp.shard_id(account_id))
  end

  def self.course_assignments(course_id)
    data = []
    next_page = "courses/#{course_id}/assignments?per_page=100"
    while next_page
      response = RubricApp.canvas_api.get(next_page)
      data << response.body.collect do |assignment|
        {
          'rubric_id' => assignment['rubric_settings']['id'],
          'rubric_title' => assignment['rubric_settings']['title'],
          'assignment_id' => assignment['id'],
          'assignment_title' => assignment['name']
        } unless assignment['rubric_settings'].nil?
      end
      next_page = RubricApp.parse_pages(response.headers[:link])['next']
    end
    data.flatten.reject(&:nil?)
  end
end
