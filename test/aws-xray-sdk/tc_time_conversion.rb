require 'aws-xray-sdk/utils/math_utils'

class TestGetTimeInSeconds < Minitest::Test
    def convert_time_from_milliseconds
        time_in_seconds = convert_time_in_seconds 1.723627099460531E12
        assert_equal time_in_seconds 1723627099.460531
    end

    def convert_time_from_seconds
        time_in_seconds = convert_time_in_seconds 1.7236270994659648E9
        assert_equal time_in_seconds 1.7236270994659648E9
    end
end