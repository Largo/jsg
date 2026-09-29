# jsg

jsg helps you set up [ruby.wasm](https://github.com/ruby/ruby.wasm) browser projects, and it adds a friendlier syntax on top of the [js gem](https://rubygems.org/gems/js).

It has two parts:

- the `jsg` command, which creates, builds and serves a project
- `require "jsg"` inside the browser, which lets you write `document.title` instead of `JS.global[:document][:title]`

jsg 0.2 targets ruby.wasm 2.10.1 and builds Ruby 4.0 for the browser.

## Installation

```bash
gem install jsg
```

This also installs `ruby_wasm`, which provides the `rbwasm` build tool. `jsg server` needs WEBrick, which is not a default gem anymore:

```bash
gem install webrick
```

## Creating a project

```bash
jsg new myapp   # copy the template into ./myapp, then run jsg build
cd myapp
jsg server      # serve the folder on http://localhost:8080 (or the next free port)
```

`jsg new myapp --skip-build` only copies the template. The project contains:

- `index.html`, with a `<script type="text/ruby">` block that requires jsg and loads `src/main.rb`
- `src/main.rb`, the place for your code
- `assets/browser.script.iife.js`, ruby.wasm's browser script, set up to load `assets/ruby-app.wasm`
- `Gemfile` with `ruby_wasm`, `js` and `jsg`
- a `.gitignore` for the `build/` and `rubies/` folders

`jsg build` runs `bundle install` and then `bundle exec rbwasm build --ruby-version 4.0 -o assets/ruby-app.wasm`. The wasm file contains Ruby and the gems from the Gemfile, not your own files: `index.html` fetches `src/main.rb` from the web server with `JS::RequireRemote`, so a page reload picks up your changes. Run `jsg build` again only when you change the Gemfile. The first build compiles CRuby and the gems for WebAssembly and takes a while. Later builds reuse the `build/` and `rubies/` folders.

## Syntax

```ruby
require "jsg"

d = JSG.document
d.getElementById("spinner").style.display = "none"

d.createElement("h2").tap do |h2|
  h2.innerText = "Examples"
  d.body.appendChild(h2)
end
```

What `require "jsg"` adds to `JS::Object`:

| You write | Result |
| --- | --- |
| `element.innerText` | property value, converted with `to_rb` |
| `element.innerText = "Hi"` | sets the property (the value is converted with `to_js`) |
| `document.getElementById("x")` | calls the method, result converted with `to_rb` |
| `element.hidden?`, `list.includes?(3)` | `true`/`false`, using JavaScript truthiness |
| `JS.global.URLSearchParams.new("a=1")` | a capitalized name without arguments returns the constructor |
| `obj.missing` | a property that is `undefined` raises `NoMethodError` |

`to_rb` converts JavaScript values to Ruby:

| JavaScript | Ruby |
| --- | --- |
| number | `Float` (`3` becomes `3.0`) |
| string | `String` |
| boolean | `true` / `false` |
| bigint | `Integer` |
| symbol | `Symbol` |
| `null` | `nil` |
| Array | `Array`, elements converted too |
| anything else, including `undefined` | stays a `JS::Object` |

More helpers:

```ruby
JSG.window        # JS.global, also JSG.w
JSG.document      # JS.global[:document], also JSG.d
JSG.q("p")        # document.querySelectorAll("p")
JSG.global        # anything else is forwarded to the JS module

list = JSG.q("li")
list.to_a         # array-like objects (NodeList, ...) to a Ruby Array
list.each { |li| li.classList.add("done") }
obj.to_a(convertTypes: false) # keep the elements as JS::Object

value.nil?        # true for null and undefined
value.undefined?  # true only for undefined
value.typeof?(:string)
el.tap { |e| ... } # like Kernel#tap (JS::Object is a BasicObject since js 2.10)
value == true     # comparing with true, false and nil works (JavaScript's == rules)
```

## Development

```bash
bin/setup
bundle exec rake    # rspec, the ruby.wasm tests and rubocop
```

The specs in `spec/` test the command line tool on your normal Ruby. `lib/jsg.rb` needs the js gem, which only works inside ruby.wasm, so its tests in `test/wasm` run the prebuilt ruby.wasm on Node.js (`bundle exec rake test:wasm`, needs Node.js and npm).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
