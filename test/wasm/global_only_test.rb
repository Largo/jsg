# frozen_string_literal: true

# Runs in its own ruby.wasm VM (see run.mjs): `require "jsg/global"` alone,
# without a separate `require "jsg"`, must load both parts.

require "jsg/global"

JS.eval("globalThis.jsgOnlyGlobal = { answer: 42 }")

checks = {
  "JSG::Global forwards JS.xxx" => -> { JS.jsgOnlyGlobal.answer.eql?(42.0) },
  "the JS::Object patch from jsg is loaded too" => -> { JS::Object.ancestors.first == JSGPatch },
  "JSG module is defined" => -> { JSG::VERSION.is_a?(String) }
}

failures = 0
checks.each do |name, check|
  if check.call == true
    puts "ok   #{name}"
  else
    failures += 1
    puts "FAIL #{name}"
  end
rescue Exception => e # rubocop:disable Lint/RescueException
  failures += 1
  puts "FAIL #{name} (#{e.class}: #{e.message})"
end
puts "#{checks.size} tests, #{failures} failures"
# `load` always returns true, so run.mjs reads the result from this global.
$global_only_test_passed = failures.zero? # rubocop:disable Style/GlobalVars
