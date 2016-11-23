require_relative './test_helper'

class RubricWorkerTest < Minitest::Test
  def test_perform
    account_id = 10
    email = 'test@example.com'
    RubricWorker.expects(:csv_headers).returns(['header1,header2'])
    RubricWorker.expects(:rubric_data_rows)
                .with(account_id)
                .returns([['data1','data2'],['data3','data4']])
    RubricWorker.expects(:send_mail)
                .with("header1,header2\ndata1,data2\ndata3,data4\n", email)
    RubricWorker.perform(account_id, email)
  end

  def test_rubric_data_rows
    account_id = 10
    account_rubric_ids = [1, 2, 3]
    account_courses = [
      {'canvas_id' => 1},
      {'canvas_id' => 2},
      {'canvas_id' => 3}
    ]
    course_assignments = [
      [{'id' => 7}],
      [],
      [{'id' => 8}, {'id' => 9}]
    ]

    RubricWorker.expects(:account_rubric_ids).with(account_id).returns(account_rubric_ids)
    RubricWorker.expects(:account_courses).returns(account_courses)
    account_courses.each_with_index do |course, i|
      RubricWorker.expects(:course_assignments)
                  .with(course['canvas_id'])
                  .returns(course_assignments[i])

      course_assignments[i].each do |assignment|
        RubricWorker.expects(:build_row)
                    .with(
                      {'canvas_id' => course['canvas_id']},
                      {'id' => assignment['id']},
                      account_rubric_ids
                    ).returns(['row', 'of', 'data', 'for', assignment['id']])
      end
    end
    expected = [
      ['row', 'of', 'data', 'for', 7],
      ['row', 'of', 'data', 'for', 8],
      ['row', 'of', 'data', 'for', 9]
    ]

    assert_equal(expected, RubricWorker.rubric_data_rows(account_id))
  end

  def test_build_row
    course = {
      'canvas_id' => 111,
      'name' => 'Test Course',
      'term' => 'Spring 2016'
    }
    assignment = {
      'assignment_title' => 'Test Assigment',
      'assignment_id' => 222,
      'rubric_title' => 'Test Rubric',
      'rubric_id' => 123
    }

    account_rubric_ids = [123]
    expected_row = [111, 'Test Course', 'Spring 2016', 'Test Assigment', 222, 'Test Rubric', 123]
    assert_equal(expected_row, RubricWorker.build_row(course, assignment, account_rubric_ids))
  end

  def test_build_row_no_match
    course = {
      'canvas_id' => 111,
      'name' => 'Test Course',
      'term' => 'Spring 2016'
    }
    assignment = {
      'assignment_title' => 'Test Assigment',
      'assignment_id' => 222,
      'rubric_title' => 'Test Rubric',
      'rubric_id' => 123
    }

    account_rubric_ids = [456]
    assert_nil RubricWorker.build_row(course, assignment, account_rubric_ids)
  end

  def test_account_rubric_ids
    rubrics = [{'id' => 123}, {'id' => 456}]
    account_id = 10
    stub_request(:get, /accounts\/#{account_id}\/rubrics/)
      .to_return(
        :body => rubrics.to_json,
        :headers => {'Content-Type' => 'application/json', :link => []})

    assert_equal([123, 456], RubricWorker.account_rubric_ids(account_id))
  end

  def test_account_courses
    courses = {}
    account_id = 10
    sharded_id = 1000010
    RubricApp.expects(:shard_id).with(account_id).returns(sharded_id)
    RubricApp.expects(:canvas_data).with(is_a(String), sharded_id).returns(courses)

    assert_equal(courses, RubricWorker.account_courses(account_id))
  end

  def test_course_assignments
    course_id = 999
    account_id = 10
    course_assignments = [{
      'id' => '111',
      'name' => 'Test Course',
      'rubric_settings' => {
        'id' => 123,
        'title' => 'Test Rubric'
      }
    },
    {
      'id' => '222',
      'name' => 'Test Course 2',
      'rubric_settings' => {
        'id' => 456,
        'title' => 'Test Rubric 2'
      }
    }]

    expected = [{
      'rubric_id'=>123,
      'rubric_title'=>'Test Rubric',
      'assignment_id'=>'111',
      'assignment_title'=>'Test Course'
    },
    {
      'rubric_id'=>456,
      'rubric_title'=>'Test Rubric 2',
      'assignment_id'=>'222',
      'assignment_title'=>'Test Course 2'
    }]

    stub_request(:get, /courses\/#{course_id}\/assignments/)
      .to_return(
        :body => course_assignments.to_json,
        :headers => {'Content-Type' => 'application/json', :link => []})

    assert_equal(expected, RubricWorker.course_assignments(course_id))
  end

  def test_send_mail
    csv_data = "header1,header2\ndata1,data2\ndata3,data4\n"
    email = 'test@example.com'
    mail_mock = OpenStruct.new(:attachments => {})
    mail_mock.expects(:deliver!)
    Mail.expects(:new).returns(mail_mock)

    RubricWorker.send_mail(csv_data, email)

    assert_equal 'Canvas <donotreply@ucdenver.edu>', mail_mock.from
    assert_equal 'test@example.com', mail_mock.to
    assert_equal 'Canvas Account Rubric Report', mail_mock.subject
    assert_equal 'Attached is your rubric report', mail_mock.body
    assert_equal csv_data, mail_mock.attachments.first[1]
  end
end
