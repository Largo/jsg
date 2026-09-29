# frozen_string_literal: true

# Tests for lib/jsg.rb. They need the js gem, so they run inside ruby.wasm:
#   cd test/wasm && npm install && npm test
# Node has no DOM, so plain objects stand in for DOM nodes.

require "jsg"

module JSGTest
  @failures = 0
  @count = 0

  def self.test(name)
    @count += 1
    result = yield
    if result == true
      puts "ok   #{name}"
    else
      @failures += 1
      puts "FAIL #{name} (got #{result.inspect})"
    end
  rescue Exception => e # rubocop:disable Lint/RescueException
    @failures += 1
    puts "FAIL #{name} (#{e.class}: #{e.message})"
  end

  def self.raises?(klass)
    yield
    false
  rescue klass
    true
  end

  def self.run # rubocop:disable Naming/PredicateMethod
    tests
    puts "#{@count} tests, #{@failures} failures"
    @failures.zero?
  end

  def self.tests
    test("JSGPatch is prepended to JS::Object") { JS::Object.ancestors.first == JSGPatch }

    obj = JS.eval(<<~JS)
      return { name: "jsg", count: 3, list: [1, "a", true, null], nested: { x: 1 },
               flag: false, empty: "", nothing: null }
    JS

    # property access with to_rb conversion
    test("string property -> String") { obj.name == "jsg" }
    test("number property -> Float") { obj.count.eql?(3.0) }
    test("array property -> Array") { obj.list == [1.0, "a", true, nil] }
    test("object property stays JS::Object") { obj.nested.is_a?(JS::Object) && obj.nested.x == 1.0 }
    test("false property -> false") { obj.flag.equal?(false) }
    test("null property -> nil") { obj.nothing.equal?(nil) }
    test("undefined property raises NoMethodError") { raises?(NoMethodError) { obj.doesNotExist } }

    # predicates use JavaScript truthiness
    test("name? is true") { obj.name?.equal?(true) }
    test("flag? is false") { obj.flag?.equal?(false) }
    test("empty? (\"\") is false") { obj.empty?.equal?(false) }
    test("missing? is false") { obj.missing?.equal?(false) }

    # setters
    test("setter with String") { (obj.name = "new") && obj[:name].to_s == "new" }
    test("setter with Integer") { (obj.count = 5) && obj[:count].typeof == "number" && obj.count == 5.0 }
    test("setter with nil sets null") do
      obj.other = nil
      obj[:other].strictly_eql?(JS::Null)
    end
    test("setter with true") { (obj.flag = true) && obj.flag?.equal?(true) }

    # method calls
    calc = JS.eval(<<~JS)
      return { add(a, b) { return a + b }, big(n) { return n > 10 }, pair() { return [1, 2] },
               none() { return null } }
    JS
    test("method call -> Float") { calc.add(1, 2).eql?(3.0) }
    test("method call -> true") { calc.big(20).equal?(true) }
    test("predicate method call") { calc.big?(5).equal?(false) }
    test("method call -> Array") { calc.pair == [1.0, 2.0] }
    test("method call -> nil") { calc.none.equal?(nil) }

    # constructors
    test("capitalized name without args returns the constructor") { JS.global.URLSearchParams.typeof?(:function) }
    params = JS.global[:URLSearchParams].new("a=1&b=2")
    test("constructor .new works") { params.get("b") == "2" }
    test("boolean method result") { params.has("a").equal?(true) && params.has("z").equal?(false) }
    test("capitalized function with args is called") { JS.global.String(42) == "42" }

    # comparisons (the js gem converts true/false/nil with to_js)
    test("== true") { JS.eval("return true") == true }
    test("== false") { JS.eval("return false") == false }
    test("null == nil") { JS::Null == nil } # rubocop:disable Style/NilComparison
    test("undefined == nil") { JS::Undefined == nil } # rubocop:disable Style/NilComparison
    test("nil? for null and undefined") { JS::Null.nil? && JS::Undefined.nil? && !obj.nil? }
    test("undefined? only for undefined") { JS::Undefined.undefined? && !JS::Null.undefined? }
    test("typeof?") { JS.eval("return 'x'").typeof?(:string) && obj.typeof?("object") }

    # to_rb
    test("to_rb number") { JS.eval("return 1.5").to_rb.eql?(1.5) }
    test("to_rb string") { JS.eval("return 'a'").to_rb == "a" }
    test("to_rb boolean") { JS.eval("return true").to_rb.equal?(true) }
    test("to_rb bigint") { JS.eval("return 10n ** 20n").to_rb == 10**20 }
    test("to_rb symbol") { JS.eval("return Symbol('s')").to_rb == :s }
    test("to_rb null") { JS::Null.to_rb.nil? }
    test("to_rb undefined stays JS::Undefined") { JS::Undefined.to_rb.strictly_eql?(JS::Undefined) }
    test("to_rb nested array") { JS.eval("return [[1], ['b']]").to_rb == [[1.0], ["b"]] }
    test("JS.try_convert_to_rb") do
      JS.try_convert_to_rb(JS.eval("return 5")) == 5.0 && JS.try_convert_to_rb("x") == "x"
    end

    # to_a and each
    array_like = JS.eval("return { length: 2, 0: 'a', 1: 'b' }")
    test("to_a on array-like") { array_like.to_a == %w[a b] }
    test("to_a(convertTypes: false)") { array_like.to_a(convertTypes: false).all?(JS::Object) }
    test("isJSArray") { JS.eval("return []").isJSArray && !array_like.isJSArray }
    test("each on array") do
      items = []
      JS.eval("return [1, 2, 3]").each { |x| items << x } # rubocop:disable Style/MapIntoArray
      items == [1.0, 2.0, 3.0]
    end
    test("each on array-like") { array_like.each.to_a == %w[a b] }
    test("each without block returns an Enumerator") { JS.eval("return [1, 2]").each.map { |x| x * 2 } == [2.0, 4.0] }
    test("each on object yields property names") { obj.each.to_a.include?(:name) }

    # Ruby conversions must not be picked up by method_missing
    test("respond_to? for properties") { obj.respond_to?(:name) && !obj.respond_to?(:zzz) }
    test("Array#flatten keeps JS objects") { [obj, [obj]].flatten.size == 2 }
    test("string interpolation") { "<#{obj.nested}>" == "<[object Object]>" }

    test("tap yields and returns the object") do
      yielded = nil
      obj.tap { |o| yielded = o }.strictly_eql?(obj) && yielded.strictly_eql?(obj)
    end

    # the js gem's own Ruby code still works on top of the patch
    test("Array#to_js") { [1, "a"].to_js.to_rb == [1.0, "a"] }
    test("JS::Object#new") { JS.global[:Object].new.typeof?(:object) }
    test("JS::Object#apply") { JS.global[:Math][:floor].apply(3.7) == 3 }

    # JSG shortcuts
    test("JSG.window / JSG.w") { JSG.window.strictly_eql?(JS.global) && JSG.w.strictly_eql?(JS.global) }
    test("JSG.global is forwarded to JS") { JSG.global.strictly_eql?(JS.global) }
    test("JSG.eval is forwarded to JS") { JSG.eval("return 2").to_rb == 2.0 }
    test("JSG.document without a DOM") { JSG.document.undefined? }
    test("JSG::VERSION") { JSG::VERSION.is_a?(String) }
  end
end
