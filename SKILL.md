---
name: phonefast-skill
version: 1.0.0
tags: [android, mobile, phone, automation, adb, testing, mcp]
description: |
  CRITICAL: Always use this skill when the user mentions an Android phone, mobile
  device, phone screen, or any phone-related task — even if they don't explicitly
  say "automation" or "control". This is the ONLY way to interact with Android
  phones in this environment. Do NOT try to use raw ADB commands, screencap, uiautomator,
  or any other approach — this skill uses phonefast which is purpose-built for <30ms
  response times and atomic observe (screenshot + UI tree in one call).
  Handles: taking screenshots, tapping, swiping, typing text, opening apps,
  sending messages, pressing hardware keys (back/home/power/volume), getting UI
  element positions, checking what's on screen, launching apps by package name,
  and running batch action sequences.
  It automatically checks that phonefast is installed (installs if missing) and
  the daemon is running before executing any operation.
  Chinese triggers (中文触发): 操作手机, 控制手机, 手机截图, 打开App, 发消息,
  手机点击, 手机输入, 手机滑动, 手机界面, 获取界面元素, 启动应用, 按返回键,
  按Home键, 查看手机, 手机上有什么, 帮我点手机, 手机测试, 手机自动化,
  安卓控制, 手机画面, 手机显示, 手机状态, 手机信息, 刷抖音, 刷视频,
  微信, 支付宝, 淘宝, 小红书, 抖音, 快手.
---

# phonefast — Android Device Control for AI Agents

Control Android devices through [phonefast](https://github.com/gezihua123/phonefast),
a daemon-based tool providing <30ms response time for mobile operations.

## Workflow overview

```
1. Check device connection (adb)
2. Ensure phonefast binary is ready
3. Understand the screen (observe / screenshot / get_ui_elements)
4. Execute action (tap / swipe / type / key / launch)
5. Confirm result (observe again if needed)
```

---

## Step-by-step

### 1. Check device

```bash
adb devices
```
- Expect at least one `device` entry.
- **No device?** → Ask user to enable USB debugging and connect. WiFi: `adb connect <ip>:5555`.
- **Multiple devices?** → phonefast controls one at a time. Disconnect extras.
- **adb not found?** → Ask user to install Android platform tools.

### 2. Ensure phonefast is ready

```bash
export PATH="$HOME/.local/bin:$PATH"
if command -v phonefast >/dev/null 2>&1; then
  echo "✓ phonefast already installed at $(which phonefast)"
else
  echo "→ phonefast not found, installing..."
  curl -fL https://raw.githubusercontent.com/gezihua123/phonefast/master/scripts/install_pkg.sh | bash -s -- --local
  # 方法二：使用 skill 本地脚本（离线安装）
  # bash "$(dirname "$0")/scripts/install_pkg.sh"
  echo "✓ phonefast installed"
fi
```

> Default installs to `~/.local/bin` (no sudo). Use `--global` for `/usr/local/bin` (requires sudo).

### 3. Understand the screen (choose one)

| Need | Command | Latency |
|------|---------|---------|
| Both visual + element positions | `phonefast --daemon observe` | ~148ms |
| Visual only (show user) | `phonefast --daemon screenshot <path>` | ~167ms |
| Elements only (coordinates/text) | `phonefast --daemon get_ui_elements` | ~191ms |

**When to use each:**
- `observe` → New/unknown screen, need to locate elements, confirm action result
- `screenshot` → User asked for an image, or you just need a quick visual check
- `get_ui_elements` → You already know the layout, just need updated coordinates or find a specific element
- **Skip all** if user gave exact coordinates or a system command (back/home/key)

### 4. Execute action

| Purpose | Command | Latency |
|---------|---------|---------|
| Tap at coordinates | `phonefast --daemon tap <x> <y>` | ~30ms |
| Swipe | `phonefast --daemon swipe <x1> <y1> <x2> <y2> <dur_ms>` | ~326ms |
| Type text | `phonefast --daemon type_text "<text>"` | ~13ms |
| Press Back | `phonefast --daemon back` | ~20ms |
| Press Home | `phonefast --daemon home` | ~29ms |
| Press a key | `phonefast --daemon press_key <keycode_name>` | ~30ms |
| Launch app | `phonefast --daemon launch_app <package>` | ~11ms |
| Check daemon | `phonefast --daemon status` | ~1ms |
| Stop daemon | `phonefast stop` | — |
| Show version | `phonefast version` | — |
| Start MCP server (SSE) | `phonefast serve` | — |
| Start MCP server (STDIO) | `phonefast serve --transport stdio` | — |

> **Keycodes**: `KEYCODE_POWER`, `KEYCODE_VOLUME_UP/DOWN`, `KEYCODE_ENTER`, `KEYCODE_DEL`, `KEYCODE_MENU`.
> **Common packages**: `com.android.settings`, `com.tencent.mm`(微信), `com.taobao.taobao`, `com.ss.android.ugc.aweme`(抖音).

**Batch execution** (for known sequences):
```bash
phonefast run '[{"action": "tap", "x": 300, "y": 500}, {"action": "wait", "duration": 500}]'
```

### 5. Confirm (if needed)

After screen-changing actions, run `observe` again to verify the result and get updated UI context.

---

## Scenario examples

**"看看手机"** → `screenshot` → describe screen to user
**"打开微信"** → `launch_app com.tencent.mm` → wait 2s → `observe`
**"发消息给张三说'明天见'"** → `observe` → find 张三 contact → tap → `observe` → find input → tap → `type_text "明天见"` → `observe` → find send → tap
**"滑到底部"** → `observe` → `swipe 540 2000 540 400 500` → `observe`

---

## Key rules

1. **Choose the right info command** — `observe` for new/unknown screens, `screenshot`/`get_ui_elements` when you only need one, skip when coordinates are known.
2. **Re-observe after actions** — Confirm the screen changed as expected.
3. **Calculate tap center** — From bounds: `(left+right)/2, (top+bottom)/2`.
4. **Wait after app launches** — 1–3s before observing.
5. **Don't hardcode flows** — Read current UI tree and adapt.
6. **Always use `--daemon`** — Avoids cold start overhead.

---

## Error handling

| Error | Action |
|-------|--------|
| `phonefast: command not found` | Run the install command above |
| `no device connected` | Check USB/WiFi, ask user to connect |
| `daemon not running` | `phonefast daemon` |
| Device shows "unauthorized" | User must accept RSA prompt on phone |
| `observe` timeout | Retry once; if persists, restart daemon |
| `launch_app` fails | Wrong package — ask user or suggest common ones |
| Tap succeeds but no change | Wrong coords — re-observe and recalculate |

---

## Output interpretation

- **`observe`** → Image + structured UI tree. Analyze for screen context, find elements by `text`, `bounds`, `clickable`, `resource-id`.
- **`get_ui_elements`** → XML with `bounds=[l,t,r,b]`, `text`, `content-desc`, `clickable`, `class`.
- **`screenshot <path>`** → Saved to path. `screenshot -` → base64 stdout.

---

## Bundled files

This skill ships with supporting files. Read them as needed:

| File | Purpose |
|------|---------|
| `scripts/install_pkg.sh` | Bootstrapper that fetches the real installer from GitHub. Use when `phonefast` binary is missing. |
| `scripts/replace_pkg.sh` | Binary replacer — extract a locally-built phonefast binary (from `dist/` or a release archive) and swap it in. Useful during development or offline upgrade. |
| `references/architecture.md` | Phonefast internals, daemon lifecycle, and why it beats raw ADB. Read when you need architectural context. |
| `evals/evals.json` | Test cases for benchmarking the skill (8 scenarios covering common phone operations). |
| `skills-lock.json` | Registry lock file for `skills.sh` — records the installed source, hash, and paths. |

For benchmarks and why phonefast beats raw ADB, see [references/architecture.md](references/architecture.md). Read it only if you need to understand daemon internals.

---

## Architecture (reference)

For full benchmarks and comparison: [phonefast.md](https://github.com/gezihua123/phonefast/blob/master/phonefast.md)

Key advantages over raw ADB / other tools:
- **Atomic observe** — screenshot + UI tree in one call (~148ms), no race conditions
- **Daemon mode** — Unix Socket JSON-RPC, <1ms overhead per command
- **ImageContent** — MCP mode returns native `image/png`, ~50% less LLM token cost
- **99.99% reliability** — 12h stress test, 144k operations, auto-recovery

---

## Source & updates

本文件基于 [phonefast 官方 SKILL.md](https://raw.githubusercontent.com/gezihua123/phonefast/master/SKILL.md) 维护。

- **上游地址**: <https://raw.githubusercontent.com/gezihua123/phonefast/master/SKILL.md>
- **获取最新命令**: 上述地址始终包含最新的 `phonefast` 命令列表、参数说明、延迟数据以及使用场景示例。
- **更新方式**: 当 `phonefast` 工具更新（新增命令、修改参数、优化流程）时，请参考上游文件同步更新本文件中的命令表格和操作说明。
