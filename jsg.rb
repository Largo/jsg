# frozen_string_literal: true

require_relative "jsg/version"
require 'js'

module JSGPatch
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    #  JS.try_convert_to_rb(obj) -> Ruby Object or JS::Object
    #
    #    Try to convert the given object to a Ruby Datatype using to_rb
    #   method. Returns the parameter as JS::Object if the object cannot be converted.
    def try_convert_to_rb(obj)
      return obj.to_rb
    end
  end

  # Instance methods to patch or add
  def to_a(convertTypes: true)
    as_array = JS.global[:Array].from(self)
    Array.new(as_array[:length].to_i) do |index|
      item = as_array[index]
      convertTypes && item.respond_to?(:to_rb) ? item.to_rb : item
    end
  end

  def to_rb
    return nil if self == JS::Null
    case self.typeof
    when "number" then self.to_f
    when "string" then self.to_s
    when "boolean" then self == JS::True
    when "symbol" then self.to_sym
    when "bigint" then self.to_i
    when "object"
      if self.isJSArray
        self.to_a
      else
        self
      end
    else
      self
    end
  end

  def isJSArray
    JS.global[:Array].isArray(self) == JS::True
  end

  def typeof?(type)
    self.typeof == type.to_s
  end


  # Support self == true instead of self == JS:True
  alias_method :orig_eq, :==
  def ==(other)
    if other.equal? true
      return orig_eq(JS::True)
    elsif other.equal? false
      return orig_eq(JS::False)
    elsif other.equal? nil
      return orig_eq(JS::Null) || orig_eq(JS::Undefined)
    end

    orig_eq(other)
  end


  def self.static_to_rb(object)
    return nil if self[sym] == JS::Null
  end

  def each(&block)
    if block_given?
      if self.isJSArray
        self.to_a.each(&block)
      else
        Array.new(__props).each(&block)
      end
    else
      to_enum(:each)
    end
  end

  def nil?
    return self == JS::Null
  end

  def undefined?
    return self == JS::Undefined
  end


  def __props
    props = []
    current_obj = self
    begin
      current_props = JS.global[:Object].getOwnPropertyNames(current_obj).to_a
      props.concat(current_props)
      current_obj = JS.global[:Object].getPrototypeOf(current_obj)
    end while current_obj != JS::Null && current_obj != JS::Undefined
    props.compact.map(&:to_sym)
  end

  def method_missing(sym, *args, &block)
    return super(sym, *args, &block) if self === JS::Null
    sym_str = sym.to_s
    sym = sym_str[0..-2].to_sym if sym_str.end_with?("?") or sym_str.end_with?("=")
    if sym_str.end_with?("?")
      # When a JS method is called with a ? suffix, it is treated as a predicate method,
      # and the return value is converted to a Ruby boolean value automatically.
      if self[sym]&.typeof?(:function)
        return self.call(sym, *args, &block) == JS::True
      end

      return self[sym] == JS::True
    end

    if sym_str.end_with?("=")
      if args[0].respond_to?(:to_js)
        return self[sym] = args[0].to_js
      end

      return self[sym] = args[0]
    end

    if self[sym]&.typeof?(:function) # Todo: What do we do when we want to copy functions around?
      begin
        result = self.call(sym, *args, &block)
        if result.typeof?(:boolean) # fixes if searchParams.has("locations")
          return result == JS::True
        else
          return result.to_rb if result.respond_to?(:to_rb)
          return result
        end
      rescue
        return self[sym] # TODO: this is necessary in cases like JS.global[:URLSearchParams]
      end
    end

    if self[sym]&.typeof?(:undefined) == false and self[sym].respond_to?(:to_rb)
      return self[sym].to_rb
    end

    return super(sym, *args, &block)
  end

end

# Applying the JSG module to JS::Object to patch existing methods and add new ones
class JS::Object
  include JSGPatch
end

# Extending the JS module to include new class methods
module JS
  extend JSGPatch::ClassMethods

end

module JSG
  def self.window(*args)
    JS.send(:global, *args)
  end

  def self.document(*args)
    JS.global.send(:document, *args)
  end

  def self.querySelectorAll(*args)
    document.querySelectorAll(*args)
  end

  singleton_class.alias_method :w, :window
  singleton_class.alias_method :d, :document
  singleton_class.alias_method :q, :querySelectorAll

  def self.method_missing(method, *args, &block)
    if JS.respond_to?(method)
      JS.send(method, *args, &block)
    else
      super
    end
  end

  def self.respond_to_missing?(method, include_private = false)
    JS.respond_to?(method, include_private) || super
  end
end
