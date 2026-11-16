// The browser's storage, or an in-memory stand-in when it is blocked (#157).
// LiveSocket reads window.localStorage and window.sessionStorage in its constructor and throws
// when either is blocked; its localStorage and sessionStorage options take a stand-in.
export function safeStorage(win, name) {
  try {
    const storage = win[name]
    storage.setItem("phx:probe", "1")
    storage.removeItem("phx:probe")
    return storage
  } catch (_e) {
    const data = new Map()
    return {
      getItem: (key) => (data.has(key) ? data.get(key) : null),
      setItem: (key, value) => data.set(key, String(value)),
      removeItem: (key) => data.delete(key),
    }
  }
}
