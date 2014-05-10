require 'rake/testtask'

Rake::TestTask.new do |t|

  $:.unshift File.dirname(__FILE__)

  t.libs.push "."
  t.test_files = FileList['spec/*_spec.rb']
  t.verbose = true
end
