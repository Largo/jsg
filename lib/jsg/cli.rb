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
    WASM_OUTPUT = "assets/ruby-app.wasm"
    # Loaded into rbwasm by `jsg build`, see the comment in that file.
    RBWASM_PATCH = File.expand_path("rbwasm_patch.rb", __dir__)
    # rbwasm downloads binaryen into the project's build/toolchain folder.
    WASM_OPT = "build/toolchain/binaryen/bin/wasm-opt"
    WASM_OPT_FEATURES = %w[--enable-bulk-memory --enable-mutable-globals
                           --enable-nontrapping-float-to-int --enable-sign-ext].freeze

    USAGE = <<~TEXT
      Usage:
        jsg new PROJECT [--skip-build]  create a new project (and build it)
        jsg build [--no-strip]          bundle install, then build assets/ruby-app.wasm (Ruby 4.0)
                                        and strip its debug info
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
        build(strip: argv.delete("--no-strip").nil?)
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

    def build(strip: true)
      system("bundle", "install") or raise Error, "bundle install failed"
      system(*homebrew_env, *rbwasm_build_command) or raise Error, "rbwasm build failed"
      strip_debug_info if strip
    end

    # With Homebrew (macOS or Linuxbrew), pkg-config may only see openssl@3:
    # - rbwasm builds a native Ruby for the host first, and its openssl
    #   extension does not compile against OpenSSL 4, Homebrew's default.
    # - psych asks pkg-config for libyaml before it uses rbwasm's WebAssembly
    #   libyaml, and would link Homebrew's native libyaml into the wasm.
    # Returns [] (no env change) without brew or when PKG_CONFIG_LIBDIR is set.
    def homebrew_env
      return [] if ENV.key?("PKG_CONFIG_LIBDIR")

      prefix = brew_prefix("openssl@3")
      return [] unless prefix

      libdir = File.join(prefix, "lib/pkgconfig")
      unless File.directory?(libdir)
        warn "warning: openssl@3 not found, the build fails with OpenSSL 4. Run: brew install openssl@3"
      end
      [{ "PKG_CONFIG_LIBDIR" => libdir }]
    end

    # `brew --prefix formula`, or nil when brew is not on the PATH.
    def brew_prefix(formula)
      prefix = IO.popen(["brew", "--prefix", formula], err: File::NULL, &:read).strip
      prefix unless prefix.empty?
    rescue SystemCallError
      nil
    end

    # Runs rbwasm with RBWASM_PATCH loaded. The patch is required by absolute
    # path, so it also works when the Gemfile pins an older jsg.
    def rbwasm_build_command
      script = "require #{RBWASM_PATCH.dump}; load Gem.bin_path(\"ruby_wasm\", \"rbwasm\")"
      ["bundle", "exec", "ruby", "-e", script, "--",
       "build", "--ruby-version", WASM_RUBY_VERSION, "-o", WASM_OUTPUT]
    end

    # Drops the DWARF debug info, which is about a third of the wasm file.
    def strip_debug_info
      wasm_opt = File.executable?(WASM_OPT) ? WASM_OPT : "wasm-opt"
      system(wasm_opt, *WASM_OPT_FEATURES, "--strip-debug", WASM_OUTPUT, "-o", WASM_OUTPUT) or
        raise Error, "#{wasm_opt} --strip-debug failed"
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
