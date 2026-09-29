# frozen_string_literal: true

require_relative "jsg/version"
require "js"

# Syntax additions for JS::Object.
#
# The module is prepended to JS::Object (not included), because the js gem
# defines method_missing, respond_to_missing?, to_a and (since js 2.10) nil?
# directly on JS::Object. An included module sits behind the class in the
# ancestor chain, so those methods would never be reached.
#
# The methods in here only use JS::Object#[], #call, #typeof and
# #strictly_eql? to talk to JavaScript, never the method_missing shortcuts,
# so they cannot recurse into themselves.
module JSGPatch
  SETTER = /\A[A-Za-z_]\w*=\z/
  PREDICATE = /\A[A-Za-z_]\w*\?\z/

  # Methods added to the JS module.
  module ClassMethods
    #  JS.try_convert_to_rb(obj) -> Ruby Object or JS::Object
    #
    #  Converts the given object to a Ruby object using to_rb. Returns the
    #  argument unchanged if it cannot be converted.
    def try_convert_to_rb(obj)
      obj.respond_to?(:to_rb) ? obj.to_rb : obj
    end
  end

  # Converts an array-like JavaScript object (Array, NodeList, arguments, ...)
  # to a Ruby Array. The elements are converted with to_rb unless
  # convertTypes is false.
  # rubocop:disable-next Naming/MethodParameterName, Naming/VariableName
  def to_a(convertTypes: true)
    as_array = JS.global[:Array].call(:from, self)
    Array.new(as_array[:length].to_i) do |index|
      item = as_array[index]
      convertTypes ? item.to_rb : item
    end
  end

  # Converts JavaScript primitives and arrays to Ruby objects:
  # number -> Float, string -> String, boolean -> true/false,
  # bigint -> Integer, symbol -> Symbol, null -> nil, Array -> Array.
  # Everything else (objects, functions, undefined) is returned as JS::Object.
  def to_rb
    case typeof
    when "number" then to_f
    when "string" then to_s
    when "boolean" then strictly_eql?(JS::True)
    when "bigint" then to_i
    when "symbol" then self[:description].to_s.to_sym
    when "object"
      return nil if strictly_eql?(JS::Null)

      isJSArray ? to_a : self
    else
      self
    end
  end

  def isJSArray # rubocop:disable Naming/MethodName, Naming/PredicateMethod
    JS.global[:Array].call(:isArray, self).strictly_eql?(JS::True)
  end

  def typeof?(type)
    typeof == type.to_s
  end

  # Iterates over the elements of an array-like object (anything with a
  # numeric length), otherwise over the property names of the object and its
  # prototype chain.
  def each(&block)
    return Enumerator.new { |yielder| each { |item| yielder << item } } unless block

    if array_like?
      to_a.each(&block)
    else
      __props.each(&block)
    end
    self
  end

  # Kernel#tap, which JS::Object lost when the js gem 2.10 made it a
  # BasicObject. (#then is left out on purpose: Promises have their own.)
  def tap
    yield self
    self
  end

  # true for JavaScript null and undefined
  def nil?
    strictly_eql?(JS::Null) || strictly_eql?(JS::Undefined)
  end

  # true only for JavaScript undefined
  def undefined?
    strictly_eql?(JS::Undefined)
  end

  # Property names of the object and its prototype chain, as Symbols.
  def __props
    object = JS.global[:Object]
    props = []
    current = self
    until current.nil?
      names = object.call(:getOwnPropertyNames, current)
      props.concat(names.to_a)
      current = object.call(:getPrototypeOf, current)
    end
    props.uniq.map(&:to_sym)
  end

  #   element.innerText = "Hello"   # sets a property (value converted with to_js)
  #   element.hidden?               # property or method result as true/false (JS truthiness)
  #   document.title                # reads a property, converted with to_rb
  #   document.getElementById("x")  # calls a method, result converted with to_rb
  #   JS.global.URLSearchParams     # capitalized name without arguments: returns the constructor
  #
  # Anything else, e.g. a property that is undefined, goes to the js gem's
  # method_missing.
  def method_missing(sym, *args, &block)
    name = sym.to_s

    if SETTER.match?(name) && args.length == 1 && block.nil?
      self[name[0..-2]] = args[0]
      return args[0]
    end

    if PREDICATE.match?(name)
      value = self[name[0..-2]]
      value = call(name[0..-2], *args, &block) if value.typeof == "function"
      return JS.global.call(:Boolean, value).strictly_eql?(JS::True)
    end

    value = self[sym]
    case value.typeof
    when "undefined"
      super
    when "function"
      # Calling a class like URLSearchParams without `new` throws, so return
      # the constructor itself and let the caller use `.new(...)`.
      return value if args.empty? && block.nil? && name.match?(/\A[A-Z]/)

      call(sym, *args, &block).to_rb
    else
      value.to_rb
    end
  end

  def respond_to_missing?(sym, _include_private = false)
    name = sym.to_s
    return true if SETTER.match?(name) || PREDICATE.match?(name)
    return false unless typeof?(:object) || typeof?(:function)

    !self[sym].undefined?
  end

  private

  def array_like?
    return false unless typeof?(:object) && !nil?

    isJSArray || self[:length].typeof?(:number)
  end
end

# Applying the patch to JS::Object. See the comment on JSGPatch for why this is
# a prepend and not an include.
class JS::Object # rubocop:disable Style/ClassAndModuleChildren
  prepend ::JSGPatch
end

module JS
  extend JSGPatch::ClassMethods
end

# Shortcuts for the global object and the document.
module JSG
  class Error < StandardError; end

  def self.window
    JS.global
  end

  def self.document
    JS.global[:document]
  end

  def self.querySelectorAll(*args) # rubocop:disable Naming/MethodName
    document.querySelectorAll(*args)
  end

  singleton_class.alias_method :w, :window
  singleton_class.alias_method :d, :document
  singleton_class.alias_method :q, :querySelectorAll

  # Forwards everything else to the JS module, e.g. JSG.global or JSG.eval.
  def self.method_missing(method, ...)
    if JS.respond_to?(method)
      JS.send(method, ...)
    else
      super
    end
  end

  def self.respond_to_missing?(method, include_private = false)
    JS.respond_to?(method, include_private) || super
  end
end
