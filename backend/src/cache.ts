/** Tiny in-memory TTL cache with a hard entry cap. No dependency — fine for a single-process
 *  MVP. Swap for Redis when you run more than one instance.
 *
 *  Bounded two ways so a flood of unique queries can't grow memory without limit:
 *   • lazy expiry on read, plus an opportunistic sweep of expired entries on write;
 *   • a maxEntries cap with oldest-first eviction (Map preserves insertion order). */
export class TtlCache<T> {
  private store = new Map<string, { value: T; expiresAt: number }>();

  constructor(private ttlMs: number, private maxEntries = 500) {}

  get(key: string): T | undefined {
    const entry = this.store.get(key);
    if (!entry) return undefined;
    if (entry.expiresAt < Date.now()) {
      this.store.delete(key);
      return undefined;
    }
    return entry.value;
  }

  set(key: string, value: T): void {
    const now = Date.now();
    // Re-insert so this key becomes "newest" for eviction ordering.
    this.store.delete(key);
    this.store.set(key, { value, expiresAt: now + this.ttlMs });
    this.sweep(now);
    // Evict oldest entries until within the cap.
    while (this.store.size > this.maxEntries) {
      const oldest = this.store.keys().next().value;
      if (oldest === undefined) break;
      this.store.delete(oldest);
    }
  }

  /** Drop expired entries so unique one-off keys don't linger until read again. */
  private sweep(now: number): void {
    for (const [key, entry] of this.store) {
      if (entry.expiresAt < now) this.store.delete(key);
    }
  }
}
