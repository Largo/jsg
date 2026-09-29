## [Unreleased]

## [0.2.1] - 2026-09-29

- First release published from GitHub Actions with RubyGems trusted publishing (`.github/workflows/release.yml`, triggered by `v*` tags).
- CI runs the ruby.wasm tests on Node.js 24. Node 22's WASI crashes once Ruby loads files from a mounted directory.

## [0.2.0] - 2026-09-29

- Fix `require "jsg"`: the library moved from the gem root to `lib/jsg.rb`, so it is on the load path.
- Fix the syntax additions never running: `JSGPatch` is now prepended to `JS::Object` instead of included. The js gem defines `method_missing`, `respond_to_missing?`, `to_a` and `nil?` on `JS::Object` itself, which shadowed the included module. With js 2.10 (where `JS::Object` is a `BasicObject`) 0.1.x also failed to load with `uninitialized constant JS::Object::JSGPatch`.
- Rewrite the helpers so they no longer call themselves recursively once active (`to_a`, `isJSArray`, `__props`).
- `?` methods use JavaScript truthiness. `undefined?` is only true for `undefined`. `each` also iterates array-like objects such as a `NodeList`.
- A capitalized name without arguments returns the constructor (`JS.global.URLSearchParams.new(...)`). Other JavaScript errors are no longer swallowed.
- Add `tap` to `JS::Object` again (lost when js 2.10 made it a `BasicObject`), so `createElement("h2").tap { ... }` works.
- Remove the `==` override. The js gem already compares with `true`, `false` and `nil`.
- The template's index.html loads `src/main.rb` with `JS::RequireRemote` instead of overriding `require_relative` globally. `rbwasm build` never packed `src/` into the wasm file.
- Update the template to ruby.wasm 2.10.1 (browser script, `js` and `ruby_wasm` gems). `jsg build` builds Ruby 4.0 with `bundle exec rbwasm`.
- `jsg new` reports errors instead of silently ignoring them, and gets a `--skip-build` option. `jsg server` accepts a port and explains how to install WEBrick when it is missing. New `jsg version`.
- The gem depends on `js` and `ruby_wasm` `~> 2.10` on every platform, and no longer on `erb` (a default gem).
- Add a README and tests (rspec for the command line tool, ruby.wasm on Node.js for `lib/jsg.rb`).

## [0.1.2] - 2024-05-18

- Don't require

## [0.1.0] - 2024-05-09

- Initial release
