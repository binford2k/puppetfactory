require 'json'
require 'rake'
require 'rspec/core/rake_task'

task :spec    => 'spec:all_agents'
task :default => :spec

desc "List all available tests"
task :list do
  Dir.glob('spec/*').sort.each do |dir|
    puts File.basename(dir, '_spec.rb')
  end
end

desc "Run each test and summarize their output"
task :generate => [:spec] do
  output = {'timestamp' => Time.now}
  Dir.glob("output/json/*.json") do |file|
    name = File.basename(file, '.json')
    data = JSON.parse(File.read(file)) rescue {}
    output[name] ||= {}
    output[name]['summary'] = data['summary']
  end

  Dir.glob("output/json/*/*.json") do |file|
    current, name = file.chomp('.json').split('/').last(2)
    data = JSON.parse(File.read(file)) rescue {}
    output[name] ||= {}
    output[name][current] = data['summary']
  end

  File.write('output/summary.json', output.to_json)
end

namespace :spec do
  targets = []
  Dir.glob('/etc/puppetlabs/code/environments/*').each do |dir|
    next unless File.directory?(dir)

    dir = File.basename(dir)
    next if dir == 'production'

    targets << dir.sub('_production', '')
  end
  task :all_agents => targets

  if ENV.include? 'current_test'
    test    = ENV['current_test']
    html    = "output/html/#{test}"
    json    = "output/json/#{test}"
    pattern = "spec/#{test}_spec.rb"
    puts "Running the #{test} test suite..."
  else
    html    = "output/html"
    json    = "output/json"
    pattern = "spec/*_spec.rb"
    puts "Running all test suites..."
  end

  FileUtils.mkdir_p html
  FileUtils.mkdir_p json

  targets.each do |target|
    desc "Run Puppetfactory tests for #{target}"
    RSpec::Core::RakeTask.new(target.to_sym) do |t|
      puts " * #{target}"
      ENV['TARGET_HOST'] = target
      t.verbose = false
      t.fail_on_error = false
      t.rspec_opts = "--format html --out #{html}/#{target}.html --format json --out #{json}/#{target}.json"
      t.pattern = pattern
    end
  end
end
