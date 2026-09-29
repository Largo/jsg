# frozen_string_literal: true

require "tmpdir"
require "rubygems/package"

RSpec.describe JSG do
  it "has a version number" do
    expect(JSG::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe "gemspec" do
    let(:spec) { Gem::Specification.load(File.expand_path("../jsg.gemspec", __dir__)) }

    it "puts lib/jsg.rb on the load path" do
      expect(spec.require_paths).to eq(["lib"])
      expect(spec.files).to include("lib/jsg.rb", "lib/jsg/version.rb", "lib/jsg/cli.rb")
    end

    it "ships the template that jsg new copies" do
      expect(spec.files).to include("template/Gemfile", "template/gitignore", "template/index.html.erb",
                                    "template/src/main.rb", "template/assets/browser.script.iife.js")
    end

    it "ships the jsg executable" do
      expect(spec.executables).to eq(["jsg"])
      expect(spec.files).to include("exe/jsg")
    end

    it "does not ship development files" do
      expect(spec.files.grep(%r{\A(\.idea|spec|test|examples|bin)/})).to be_empty
    end
  end

  describe JSG::CLI do
    around do |example|
      Dir.mktmpdir { |dir| @dir = dir and example.run }
    end

    def create(name = "myapp")
      expect { JSG::CLI.create_project(name, dir: @dir) }.to output.to_stdout
      File.join(@dir, name)
    end

    it "creates a project from the template" do
      project = create
      files = Dir.glob("**/*", File::FNM_DOTMATCH, base: project).reject { |f| File.directory?(File.join(project, f)) }
      expect(files).to contain_exactly(".gitignore", "Gemfile", "index.html", "src/main.rb",
                                       "assets/browser.script.iife.js")
    end

    it "renders the project name into index.html" do
      html = File.read(File.join(create("hello_wasm"), "index.html"))
      expect(html).to include("<title>hello_wasm</title>", "<h1>hello_wasm</h1>")
      expect(html).not_to include("<%")
    end

    it "uses the same ruby.wasm version in the Gemfile and the browser script" do
      project = create
      gemfile = File.read(File.join(project, "Gemfile"))
      script = File.read(File.join(project, "assets/browser.script.iife.js"))
      script_version = script[/var version = "([\d.]+)"/, 1]
      expect(gemfile).to include(%(gem "ruby_wasm", "~> #{script_version}"), %(gem "js", "~> #{script_version}"))
      expect(script).to include('var name = "@ruby/4.0-wasm-wasi"', "fetch(`assets/ruby-app.wasm`)")
    end

    it "refuses to overwrite an existing folder" do
      Dir.mkdir(File.join(@dir, "taken"))
      expect { JSG::CLI.create_project("taken", dir: @dir) }.to raise_error(JSG::Error, /already exists/)
    end

    it "jsg new --skip-build creates the project without building" do
      Dir.chdir(@dir) do
        expect(JSG::CLI).not_to receive(:build)
        expect { expect(JSG::CLI.run(%w[new myapp --skip-build])).to eq(0) }
          .to output(%r{create myapp/index.html}).to_stdout
      end
      expect(File).to exist(File.join(@dir, "myapp/index.html"))
    end

    it "jsg new without a name fails with usage" do
      expect { expect(JSG::CLI.run(%w[new])).to eq(1) }.to output(/Project name is required/).to_stderr
    end

    it "jsg with an unknown command fails with usage" do
      expect { expect(JSG::CLI.run(%w[frobnicate])).to eq(1) }.to output(/Unknown command/).to_stderr
    end

    it "jsg version prints the version" do
      expect { JSG::CLI.run(%w[version]) }.to output("#{JSG::VERSION}\n").to_stdout
    end
  end
end
