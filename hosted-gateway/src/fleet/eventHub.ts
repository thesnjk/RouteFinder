import type { FleetDispatchEvent } from '../types.js'

type Listener = (event: FleetDispatchEvent) => void

/** In-process fan-out hub for fleet SSE events (FleetEventHub-compatible). */
export class EventHub {
  private readonly subscribers = new Map<string, Map<string, Listener>>()
  readonly heartbeatIntervalSeconds: number

  constructor(heartbeatIntervalSeconds = 15) {
    this.heartbeatIntervalSeconds = heartbeatIntervalSeconds
  }

  subscribe(vehicleId: string, listener: Listener): () => void {
    const id = crypto.randomUUID()
    let bucket = this.subscribers.get(vehicleId)
    if (!bucket) {
      bucket = new Map()
      this.subscribers.set(vehicleId, bucket)
    }
    bucket.set(id, listener)
    return () => {
      const current = this.subscribers.get(vehicleId)
      if (!current) return
      current.delete(id)
      if (current.size === 0) this.subscribers.delete(vehicleId)
    }
  }

  publish(event: FleetDispatchEvent): void {
    const bucket = this.subscribers.get(event.vehicleId)
    if (!bucket) return
    for (const listener of bucket.values()) {
      listener(event)
    }
  }
}
