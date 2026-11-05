// Runs the Ruby test files inside the prebuilt ruby.wasm (Ruby 4.0, js gem 2.10.1)
// with ../../lib mounted, so `require "jsg"` loads the gem's real source.
// Each file gets a fresh VM, so one file's requires cannot leak into another.
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WASI } from "node:wasi";
import { RubyVM } from "@ruby/wasm-wasi";

const here = path.dirname(fileURLToPath(import.meta.url));
const wasm = path.join(here, "node_modules/@ruby/4.0-wasm-wasi/dist/ruby+stdlib.wasm");
const module = await WebAssembly.compile(await fs.readFile(wasm));

async function runInFreshVM(rubyCode) {
  const wasi = new WASI({
    version: "preview1",
    returnOnExit: true,
    preopens: { "/jsg-lib": process.env.JSG_LIB ?? path.resolve(here, "../../lib"), "/jsg-test": here },
  });
  const { vm } = await RubyVM.instantiateModule({ module, wasip1: wasi });
  return vm.eval(`
    $LOAD_PATH.unshift("/jsg-lib")
    $stdout.sync = true
    ${rubyCode}
  `).toJS();
}

const results = [
  await runInFreshVM(`load "/jsg-test/jsg_test.rb"; JSGTest.run`),
  await runInFreshVM(`load "/jsg-test/global_only_test.rb"; $global_only_test_passed`),
];
process.exit(results.every(Boolean) ? 0 : 1);
