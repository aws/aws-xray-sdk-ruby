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
