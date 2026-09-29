// Runs jsg_test.rb inside the prebuilt ruby.wasm (Ruby 4.0, js gem 2.10.1)
// with ../../lib mounted, so `require "jsg"` loads the gem's real source.
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WASI } from "node:wasi";
import { RubyVM } from "@ruby/wasm-wasi";

const here = path.dirname(fileURLToPath(import.meta.url));
const wasm = path.join(here, "node_modules/@ruby/4.0-wasm-wasi/dist/ruby+stdlib.wasm");
const module = await WebAssembly.compile(await fs.readFile(wasm));
const wasi = new WASI({
  version: "preview1",
  returnOnExit: true,
  preopens: { "/jsg-lib": process.env.JSG_LIB ?? path.resolve(here, "../../lib"), "/jsg-test": here },
});
const { vm } = await RubyVM.instantiateModule({ module, wasip1: wasi });
const passed = vm.eval(`
  $LOAD_PATH.unshift("/jsg-lib")
  load "/jsg-test/jsg_test.rb"
  $stdout.sync = true
  JSGTest.run
`);
process.exit(passed.toJS() ? 0 : 1);
