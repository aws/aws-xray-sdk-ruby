require 'bundler/gem_tasks'

Rake::Task['release'].clear

# default task
task default: %i[yard test]

require 'rake'
require 'rake/testtask'
require 'yard'

# tasks
desc 'execute all tests'
Rake::TestTask.new :test do |t|
  t.test_files = FileList['test/**/tc_*.rb']
  t.verbose = false
  t.warning = false
end

desc 'execute distribution channel check'
Rake::TestTask.new :test_distribution do |t|
  t.test_files = FileList['test/test_distribution.rb']
  t.libs = []
  t.verbose = false
  t.warning = false
end

desc 'generate API reference documentation'
YARD::Rake::YardocTask.new :yard do |t|
  t.files = ['lib/**/*.rb']
end
