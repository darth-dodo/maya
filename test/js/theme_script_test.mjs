// The inline head theme script from root.html.heex, run against a stub page (#150 review F2).
import {test} from "node:test"
import assert from "node:assert/strict"
import {readFileSync} from "node:fs"
import vm from "node:vm"

const heex = readFileSync(new URL("../../lib/maya_web/components/layouts/root.html.heex", import.meta.url), "utf8")
const script = heex.match(/<script>([\s\S]*?)<\/script>/)[1]
assert.match(script, /"phx:theme"/, "the first inline script in root.html.heex is not the theme script")

// storage: an object with getItem/setItem, or null for blocked storage (the getter throws).
function run({storage, prefersDark}) {
  const attrs = {}
  const clicks = []
  const context = {
    document: {
      documentElement: {setAttribute: (k, v) => (attrs[k] = v), getAttribute: (k) => attrs[k]},
      addEventListener: (type, fn) => type === "click" && clicks.push(fn),
    },
    window: {addEventListener: () => {}},
    matchMedia: () => ({matches: prefersDark, addEventListener: () => {}}),
  }
  Object.defineProperty(context, "localStorage", {
    get() {
      if (!storage) throw new Error("SecurityError: storage is blocked")
      return storage
    },
  })
  vm.runInNewContext(script, context)
  const tap = () => clicks.forEach((fn) => fn({target: {closest: (s) => (s === "#theme-toggle" ? {} : null)}}))
  return {theme: () => attrs["data-theme"], tap}
}

function memoryStorage(initial = {}) {
  const data = {...initial}
  return {getItem: (k) => data[k] ?? null, setItem: (k, v) => (data[k] = String(v)), data}
}

test("blocked storage: the theme follows the phone and the toggle still switches it", () => {
  for (const prefersDark of [true, false]) {
    const page = run({storage: null, prefersDark})
    assert.equal(page.theme(), prefersDark ? "dark" : "light")
    page.tap()
    assert.equal(page.theme(), prefersDark ? "light" : "dark")
    page.tap()
    assert.equal(page.theme(), prefersDark ? "dark" : "light")
  }
})

test("storage that reads but throws on write: the toggle still switches", () => {
  const storage = {getItem: () => null, setItem: () => { throw new Error("QuotaExceededError") }}
  const page = run({storage, prefersDark: false})
  assert.equal(page.theme(), "light")
  page.tap()
  assert.equal(page.theme(), "dark")
})

test("a stored choice wins over the phone and a tap stores the new one", () => {
  const storage = memoryStorage({"phx:theme": "light"})
  const page = run({storage, prefersDark: true})
  assert.equal(page.theme(), "light")
  page.tap()
  assert.equal(page.theme(), "dark")
  assert.equal(storage.data["phx:theme"], "dark")
})

test("an old stored \"system\" follows the phone", () => {
  const page = run({storage: memoryStorage({"phx:theme": "system"}), prefersDark: true})
  assert.equal(page.theme(), "dark")
})
