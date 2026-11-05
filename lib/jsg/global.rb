# frozen_string_literal: true

require "jsg"

module JSG
  # Opt-in shortcut: forwards unknown methods on the JS module to JS.global,
  # so browser globals can be used without writing JS.global every time.
  #
  #   require "jsg/global"
  #
  #   JS.document.title           # JS.global.document.title
  #   JS.alert("Hello")           # JS.global.alert("Hello")
  #   JS.localStorage.getItem("k")
  #   JS.myValue = 1              # sets window.myValue
  #
  # It is a separate file because it changes the JS module itself, which the
  # js gem and other libraries also use. `require "jsg"` alone does not load it.
  #
  # Only names that JS does not already answer are forwarded. These keep their
  # Ruby meaning, so use JS.global for the browser global of the same name:
  #
  # - methods of the js gem: JS.global, JS.eval, JS.try_convert, JS.is_a?, ...
  # - methods every Ruby module has: JS.name (returns "JS", not window.name),
  #   JS.hash, JS.inspect, JS.class, JS.method, JS.display, JS.freeze, ...
  #
  # Private Kernel methods such as open, print or format are forwarded, because
  # calling them with an explicit receiver (JS.open) ends up in method_missing.
  # A name the global object does not have raises NoMethodError as usual.
  module Global
    # Sends +name+ with its arguments and block to JS.global if the global
    # object responds to it (property read, setter, method call or predicate,
    # as handled by the jsg patch); otherwise raises NoMethodError via super.
    def method_missing(name, ...)
      return super unless global.respond_to?(name)

      global.__send__(name, ...)
    end

    # Makes JS.respond_to?(name) true for the names method_missing forwards.
    def respond_to_missing?(name, include_private = false)
      global.respond_to?(name) || super
    end
  end
end

JS.extend(JSG::Global)
