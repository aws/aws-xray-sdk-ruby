0.16.0 (2024-09-05)
-------------------
* Update - Fix issue: Wrong duration for DB transaction event on ROR 7.1 [PR #96](https://github.com/aws/aws-xray-sdk-ruby/pull/96)
  
0.15.0 (2023-10-18)
-------------------
* Update - Add ECS metadata allowing cloudwatch-logs to be linked with traces [PR #93](https://github.com/aws/aws-xray-sdk-ruby/pull/93)

0.14.0 (2023-04-05)
-------------------
* Added - Allow list TopicArn for SNS PublishBatch request [PR #82](https://github.com/aws/aws-xray-sdk-ruby/pull/82).
* Update - Change context missing strategy behaviour to Log Error [PR #83](https://github.com/aws/aws-xray-sdk-ruby/pull/83).
* Added - Prevent warnings variable @metadata not initialised [PR #86](https://github.com/aws/aws-xray-sdk-ruby/pull/86).

0.13.0 (2022-01-04)
-------------------
* Added - Whitelist the LocationService client for instrumentation [PR #77](https://github.com/aws/aws-xray-sdk-ruby/pull/77).

0.12.0 (2021-04-01)
-------------------
* Added - Added support for Rails 6.1 ActiveRecord [PR #57](https://github.com/aws/aws-xray-sdk-ruby/pull/57)
* Fixed - Fixed grammar of log messages [PR #61](https://github.com/aws/aws-xray-sdk-ruby/pull/61)

0.11.5 (2020-06-10)
-------------------
* Added - Added support for IMDSv2 for EC2 metadata [PR #48](https://github.com/aws/aws-xray-sdk-ruby/pull/48)

0.11.4 (2020-03-31)
-------------------
* Bugfix - Fixed issue where wrong DB-connection was returned [PR #35](https://github.com/aws/aws-xray-sdk-ruby/pull/35)
* Added - Whitelist SageMakerRuntime InvokeEndpoint operation [PR #36](https://github.com/aws/aws-xray-sdk-ruby/pull/36)
* Bugfix - Do not log Lambda runtime segments [PR #39](https://github.com/aws/aws-xray-sdk-ruby/pull/39)
* Bugfix - Fix typo of aws services white list [PR #41](https://github.com/aws/aws-xray-sdk-ruby/pull/41)
* Added - Add missing rds data service sdk [PR #42](https://github.com/aws/aws-xray-sdk-ruby/pull/42)
* Added - Updated service whitelist [PR #43](https://github.com/aws/aws-xray-sdk-ruby/pull/43)
* Bugfix - Use full qualified constant name [PR #45](https://github.com/aws/aws-xray-sdk-ruby/pull/45)

0.11.3 (2019-10-31)
-------------------
* Added - Lambda instrumentation support [PR #32](https://github.com/aws/aws-xray-sdk-ruby/pull/32)

0.11.2 (2019-07-18)
-------------------
* Added - AWS SNS service whitelist support [PR #29](https://github.com/aws/aws-xray-sdk-ruby/pull/29)
* Bugfix - Fixed typo for Firehose client in AWS service manifest file [Issue #26](https://github.com/aws/aws-xray-sdk-ruby/issues/26), [PR #27](https://github.com/aws/aws-xray-sdk-ruby/pull/27)
* Bugfix - Fixed custom daemon address configuration [PR #18](https://github.com/aws/aws-xray-sdk-ruby/pull/18)
* Bugfix - Fixed trace header in the HTTP response for JS apps[PR #16](https://github.com/aws/aws-xray-sdk-ruby/pull/16)
* Fixed broken travis CI [PR #24](https://github.com/aws/aws-xray-sdk-ruby/pull/24)

0.11.1 (2018-10-09)
-------------------
* Bugfix - Fixed an issue where sampling rule poller is terminated on Puma clustered mode. [ISSUE#14](https://github.com/aws/aws-xray-sdk-ruby/issues/14)

0.11.0 (2018-09-25)
-------------------
* **Breaking**: The default sampler now launches background tasks to poll sampling rules from X-Ray service. See more details on how to create sampling rules: https://docs.aws.amazon.com/xray/latest/devguide/xray-console-sampling.html.
* **Breaking**: The sampling modules related to local sampling rules have been renamed and moved to `sampling/local` namespace.
* **Breaking**: The default json serializer is switched to `multi_json` for experimental JRuby support. Now you need to specify `oj` or `jrjackson` in Gemfile. [PR#5](https://github.com/aws/aws-xray-sdk-ruby/pull/5)
* **Breaking**: The SDK now requires `aws-sdk-xray` >= `1.4.0`.
* Feature: Environment variable `AWS_XRAY_DAEMON_ADDRESS` now takes an additional notation in `tcp:127.0.0.1:2000 udp:127.0.0.2:2001` to set TCP and UDP destination separately. By default it assumes a X-Ray daemon listening to both UDP and TCP traffic on `127.0.0.1:2000`.
* Bugfix - Call only once if `current_entity` is nil. [PR#9](https://github.com/aws/aws-xray-sdk-ruby/pull/9)

0.10.2 (2018-03-30)
-------------------
* Feature - Added SDK and Ruby runtime information to sampled segments.

0.10.1 (2018-02-21)
-------------------
* Bugfix - Fixed an issue where patched net/http returns incorrect reponse object. [ISSUE#2](https://github.com/aws/aws-xray-sdk-ruby/issues/2)
* Bugfix - Fixed an issue where client ip is set incorrectly if the ip address is retrieved from header `X-Forwarded-For`. [ISSUE#3](https://github.com/aws/aws-xray-sdk-ruby/issues/3)

0.10.0 (2018-01-22)
-------------------
* Bugfix - Fixed an issue where subsegment captures could break even if `context_missing` is set to `LOG_ERROR`.
* Bugfix - Fixed gemspec to have the correct Ruby version requirement.
