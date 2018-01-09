require_relative '../test_helper'
require 'aws-xray-sdk'
require 'aws-sdk-s3'
require 'aws-sdk-dynamodb'

# Test subsegments recording on AWS Ruby SDK
class TestAwsSdk < Minitest::Test
  @@recorder = XRay::Recorder.new
  config = {
    sampling: false,
    emitter: XRay::TestHelper::StubbedEmitter.new,
    patch: %I[aws_sdk]
  }
  @@recorder.configure(config)
  Aws.config.update xray_recorder: @@recorder

  def setup
    @@recorder.context.clear!
    @@recorder.emitter.clear
  end

  def teardown
    @@recorder.context.clear!
    @@recorder.emitter.clear
  end

  # By default the X-Ray SDK doesn't have parameter whitelisting for S3 APIs.
  def test_simple_s3_call
    @@recorder.begin_segment name
    s3 = Aws::S3::Client.new(stub_responses: true)
    bucket_data = s3.stub_data(:list_buckets, buckets: [{ name: '1' }, { name: '2' }])
    s3.stub_responses(:list_buckets, bucket_data)
    s3.list_buckets
    @@recorder.end_segment
    subsegment = @@recorder.emitter.entities[0].subsegments[0]

    assert_equal 'aws', subsegment.namespace
    aws_meta = subsegment.aws
    assert_equal 'ListBuckets', aws_meta[:operation]
  end

  def test_return_list_count
    @@recorder.begin_segment name
    dynamodb = Aws::DynamoDB::Client.new(stub_responses: true)
    table_list = dynamodb.stub_data(:list_tables, table_names: %w[t1 t2])
    dynamodb.stub_responses(:list_tables, table_list)
    dynamodb.list_tables
    @@recorder.end_segment
    subsegment = @@recorder.emitter.entities[0].subsegments[0]

    assert_equal 'aws', subsegment.namespace
    aws_meta = subsegment.aws
    assert_equal 'ListTables', aws_meta[:operation]
    assert_equal 2, aws_meta[:table_count]
    refute aws_meta.key?(:table_names)
  end

  def test_capture_map_keys
    @@recorder.begin_segment name
    dynamodb = Aws::DynamoDB::Client.new(stub_responses: true)

    mocked_req = {
      request_items: {
        table1: {
          keys: [{ id: 1 }]
        },
        table2: {
          keys: [{ id: 2 }]
        }
      }
    }

    mocked_resp = {
      consumed_capacity: [
        {
          table_name: 'table1',
          capacity_units: 1.0
        },
        {
          table_name: 'table2',
          capacity_units: 2.0
        }
      ]
    }

    resp = dynamodb.stub_data(:batch_get_item, mocked_resp)
    dynamodb.stub_responses(:batch_get_item, resp)
    dynamodb.batch_get_item mocked_req
    @@recorder.end_segment
    subsegment = @@recorder.emitter.entities[0].subsegments[0]

    assert_equal 'aws', subsegment.namespace
    aws_meta = subsegment.aws
    assert_equal 'BatchGetItem', aws_meta[:operation]
    assert_equal %w[table1 table2], aws_meta[:table_names].sort
    assert_equal mocked_resp[:consumed_capacity], aws_meta[:consumed_capacity]
  end

  def test_capiture_client_error
    @@recorder.begin_segment name
    s3 = Aws::S3::Client.new(stub_responses: true)
    s3.stub_responses(:head_bucket, Timeout::Error)
    # makes sure the capture code doesn't swallow the error
    assert_raises Timeout::Error do
      s3.head_bucket bucket: 'my_bucket'
    end
    @@recorder.end_segment
    subsegment = @@recorder.emitter.entities[0].subsegments[0]
    ex_h = subsegment.to_h[:cause][:exceptions][0]
    assert_equal 'Timeout::Error', ex_h[:message]
    assert_equal 'Timeout::Error', ex_h[:type]
  end
end
