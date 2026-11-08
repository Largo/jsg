# frozen_string_literal: true

# Loaded by `jsg build` into the rbwasm process, never inside ruby.wasm.
#
# Works around a ruby_wasm 2.10.x bug: when the host Ruby is installed with
# prefix /usr/local (the default, and the official ruby:* Docker images),
# the cross-compiled Ruby's rbconfig.rb also reports prefix /usr/local. mkmf
# then finds the host's installed headers at RbConfig::CONFIG["rubyhdrdir"]
# and compiles extensions such as the js gem against them instead of the
# build tree, which fails with "'ruby/config.h' file not found".
#
# The fix points rubyhdrdir at a path that does not exist before mkmf
# checks it, so mkmf falls back to the build tree headers ($top_srcdir and
# $extout), as it does on hosts without /usr/local Ruby.
require "delegate"
require "ruby_wasm"

module JSG
  module RbwasmPatch
    HOST_HEADERS_FIX = 'require "rbconfig"; ' \
                       'RbConfig::CONFIG["rubyhdrdir"] = File.join(RbConfig::CONFIG["topdir"], "include-not-installed")'

    # Inserts HOST_HEADERS_FIX into the extconf.rb command line.
    class ExtconfExecutor < SimpleDelegator
      def system(*args, **kwargs)
        index = args.index("--disable=gems")
        args = args.dup.insert(index + 1, "-e", HOST_HEADERS_FIX) if index
        __getobj__.system(*args, **kwargs)
      end
    end

    # Prepended to RubyWasm::CrossRubyExtProduct.
    module CrossRubyExtProduct
      def do_legacy_extconf(executor, crossruby)
        super(ExtconfExecutor.new(executor), crossruby)
      end
    end
  end
end

RubyWasm::CrossRubyExtProduct.prepend(JSG::RbwasmPatch::CrossRubyExtProduct)
