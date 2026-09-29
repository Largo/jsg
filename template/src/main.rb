# Your code goes here. index.html loads this file from the web server with
# JS::RequireRemote, so reload the page after changing it. Only changes to
# the Gemfile need a new `jsg build`.

d = JSG.document

d.createElement("p").tap do |p|
  p.innerText = "Hello from Ruby #{RUBY_VERSION}!"
  d.body.appendChild(p)
end
