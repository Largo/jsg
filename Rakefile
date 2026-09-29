# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

namespace :test do
  desc "Run the lib/jsg.rb tests inside ruby.wasm on Node.js (needs node and npm)"
  task :wasm do
    Dir.chdir("test/wasm") do
      sh "npm ci"
      sh "npm test"
    end
  end
end

task default: %i[spec test:wasm rubocop]
