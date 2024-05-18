# frozen_string_literal: true

require_relative "lib/jsg/version"

Gem::Specification.new do |spec|
  spec.name = "jsg"
  spec.version = JSG::VERSION
  spec.authors = ["Andi"]
  spec.email = ["largo@users.noreply.github.com"]

  spec.summary = "JSG helps setting up ruby.wasm projects and comes with a nicer syntax"
  spec.description = "JSG helps setting up ruby.wasm projects and comes with a nicer syntax"
  spec.homepage = "https://github.com/largo/jsg"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/largo/jsg"
  spec.metadata["changelog_uri"] = "https://github.com/largo/jsg/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ examples/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "erb" unless RUBY_PLATFORM.start_with? "wasm"
  spec.add_dependency "ruby_wasm" unless RUBY_PLATFORM.start_with? "wasm"
  spec.add_dependency "js", "~> 2.6" if RUBY_PLATFORM.start_with? "wasm"
end
