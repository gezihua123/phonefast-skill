# phonefast Architecture Reference

For full benchmarks and comparison: [phonefast.md](https://github.com/gezihua123/phonefast/blob/master/phonefast.md)

## Why phonefast instead of raw ADB?

| Capability | Raw ADB | phonefast |
|------------|---------|-----------|
| Screenshot + UI tree (atomic) | Two separate calls, race conditions | `observe` — one call, 148ms |
| Command latency | ~30-100ms per `adb shell` | ~1ms via Unix socket |
| MCP image output | Base64 encoded | Native `image/png` (~50% less token cost) |
| Reliability | Manual retry logic | Auto-recovery, 99.99% uptime |

## Key advantages

- **Atomic observe** — screenshot + UI tree in one call (148ms), no race conditions between what you see and what the device shows
- **Daemon mode** — Unix Socket JSON-RPC, <1ms overhead per command after first connection
- **ImageContent** — MCP mode returns native `image/png`, ~50% less LLM token cost compared to base64
- **99.99% reliability** — 12h stress test, 144k operations with automatic recovery

## Daemon lifecycle

```
phonefast daemon   → start daemon (required before any command)
phonefast --daemon observe  → daemon already running, just send command
phonefast stop     → stop daemon
```

Always use `--daemon` to reuse an existing daemon connection instead of starting a new one per command.
