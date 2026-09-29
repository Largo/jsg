# frozen_string_literal: true

# These specs run on the host Ruby. lib/jsg.rb needs the js gem, which only
# works inside ruby.wasm, so it is tested separately in test/wasm.
require "jsg/cli"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
