// The storage handed to LiveSocket when the browser blocks storage (#157).
import {test} from "node:test"
import assert from "node:assert/strict"
import {safeStorage} from "../../assets/js/safe_storage.js"

const blocked = {
  get localStorage() { throw new Error("SecurityError: The operation is insecure.") },
}

test("blocked storage: an in-memory stand-in that reads back what was set", () => {
  const storage = safeStorage(blocked, "localStorage")
  assert.equal(storage.getItem("phx:x"), null)
  storage.setItem("phx:x", 1)
  assert.equal(storage.getItem("phx:x"), "1")
  storage.removeItem("phx:x")
  assert.equal(storage.getItem("phx:x"), null)
})

test("storage that throws on write: the in-memory stand-in", () => {
  const real = {getItem: () => null, setItem: () => { throw new Error("QuotaExceededError") }, removeItem: () => {}}
  const storage = safeStorage({sessionStorage: real}, "sessionStorage")
  assert.notEqual(storage, real)
  storage.setItem("k", "v")
  assert.equal(storage.getItem("k"), "v")
})

test("working storage: the browser's own object, unchanged", () => {
  const data = {}
  const real = {getItem: (k) => data[k] ?? null, setItem: (k, v) => (data[k] = v), removeItem: (k) => delete data[k]}
  assert.equal(safeStorage({localStorage: real}, "localStorage"), real)
})
