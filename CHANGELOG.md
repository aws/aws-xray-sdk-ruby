0.10.1 (2018-02-21)
-------------------
* Bugfix - Fixed an issue where patched net/http returns incorrect reponse object. [ISSUE#2](https://github.com/aws/aws-xray-sdk-ruby/issues/2)
* Bugfix - Fixed an issue where client ip is set incorrectly if the ip address is retrieved from header `X-Forwarded-For`. [ISSUE#3](https://github.com/aws/aws-xray-sdk-ruby/issues/3)

0.10.0 (2018-01-22)
-------------------
* Bugfix - Fixed an issue where subsegment captures could break even if `context_missing` is set to `LOG_ERROR`.
* Bugfix - Fixed gemspec to have the correct Ruby version requirement.
