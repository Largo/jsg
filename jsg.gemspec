# frozen_string_literal: true

require_relative "lib/jsg/version"

Gem::Specification.new do |spec|
  spec.name = "jsg"
  spec.version = JSG::VERSION
  spec.authors = ["Andi"]
  spec.email = ["largo@users.noreply.github.com"]

  spec.summary = "JSG helps setting up ruby.wasm projects and comes with a nicer syntax"
  spec.description = "The jsg command creates, builds and serves ruby.wasm browser projects. " \
                     "require \"jsg\" adds property access, setters, predicates and Ruby type " \
                     "conversion to the js gem's JS::Object."
  spec.homepage = "https://github.com/largo/jsg"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/largo/jsg/blob/main/CHANGELOG.md"

  # Everything `require "jsg"` and `jsg new` need. Listed explicitly instead of
  # `git ls-files` so that editor folders and test fixtures stay out of the gem.
  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "exe/*", "sig/*.rbs", "template/**/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
      .select { |f| File.file?(f) }
  end
  spec.bindir = "exe"
  spec.executables = ["jsg"]
  spec.require_paths = ["lib"]

  # A gemspec is evaluated when the gem is built, not when it is installed, so
  # platform checks on RUBY_PLATFORM here would bake in the build machine's
  # platform. Declare what both sides need instead:
  # - js: lib/jsg.rb runs inside ruby.wasm (on the host it installs as a stub)
  # - ruby_wasm: provides the rbwasm command that `jsg build` runs
  # erb is a default gem, and webrick is only needed for `jsg server`, which
  # tells you to install it when it is missing.
  spec.add_dependency "js", "~> 2.10"
  spec.add_dependency "ruby_wasm", "~> 2.10"
end
