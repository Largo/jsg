# frozen_string_literal: true

require "erb"
require "fileutils"
require_relative "version"

module JSG
  class Error < StandardError; end

  # The `jsg` command line tool. Runs on the host, not inside ruby.wasm,
  # so it must not require "js".
  module CLI
    TEMPLATE_PATH = File.expand_path("../../template", __dir__)
    # Ruby version that `jsg build` compiles to WebAssembly. Matches the
    # @ruby/4.0-wasm-wasi browser script in template/assets.
    WASM_RUBY_VERSION = "4.0"

    USAGE = <<~TEXT
      Usage:
        jsg new PROJECT [--skip-build]  create a new project (and build it)
        jsg build                       bundle install, then build assets/ruby-app.wasm (Ruby 4.0)
        jsg server [PORT]               serve the current directory (default port 8080)
        jsg version                     print the jsg version
    TEXT

    module_function

    def run(argv)
      command = argv.shift
      case command
      when "new"
        skip_build = !argv.delete("--skip-build").nil?
        project_name = argv.shift
        return usage_error("Error: Project name is required.") unless project_name

        destination = create_project(project_name)
        Dir.chdir(destination) { build } unless skip_build
      when "build"
        build
      when "serve", "server"
        server(port: Integer(argv.shift || 8080))
      when "version", "-v", "--version"
        puts VERSION
      else
        return usage_error("Unknown command: #{command}") if command

        puts USAGE
      end
      0
    rescue Error => e
      warn e.message
      1
    end

    def usage_error(message)
      warn message
      warn USAGE
      1
    end

    # Copies the template into dir/project_name. Files ending in .erb are
    # rendered with project_name available. Returns the destination path.
    def create_project(project_name, dir: Dir.pwd)
      destination = File.join(dir, project_name)
      if File.exist?(destination)
        raise Error, "Sorry, #{destination} already exists. Please choose another name or delete the folder."
      end

      Dir.glob("**/*", base: TEMPLATE_PATH).sort.each do |relative_path|
        source = File.join(TEMPLATE_PATH, relative_path)
        next if File.directory?(source)

        content = File.read(source)
        content = ERB.new(content).result_with_hash(project_name: project_name) if relative_path.end_with?(".erb")

        target = relative_path.delete_suffix(".erb")
        target = target.sub(%r{(\A|/)gitignore\z}, "\\1.gitignore")
        target_path = File.join(destination, target)
        FileUtils.mkdir_p(File.dirname(target_path))
        File.write(target_path, content)
        puts "create #{File.join(project_name, target)}"
      end
      destination
    end

    def build
      system("bundle", "install") or raise Error, "bundle install failed"
      system("bundle", "exec", "rbwasm", "build", "--ruby-version", WASM_RUBY_VERSION, "-o", "assets/ruby-app.wasm") or
        raise Error, "rbwasm build failed"
    end

    def server(port: 8080)
      begin
        require "webrick"
      rescue LoadError
        raise Error, "jsg server needs the webrick gem. Install it with: gem install webrick"
      end

      loop do
        server = WEBrick::HTTPServer.new(BindAddress: "0.0.0.0", Port: port, DocumentRoot: Dir.pwd)
        trap("INT") { server.shutdown }
        puts "Serving #{Dir.pwd} at http://localhost:#{port}"
        server.start
        break
      rescue Errno::EADDRINUSE
        port += 1
      end
    end
  end
end
