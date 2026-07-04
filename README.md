# phonefast-skill

> Android device control skill for AI agents — tap, swipe, type, screenshot, and more via [phonefast](https://github.com/gezihua123/phonefast).

## What this is

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that enables AI agents to control Android phones. When a user says "看看手机", "帮我点手机", or any Android automation request, this skill handles device connection, screen understanding, and action execution.

## Files

```
├── SKILL.md               # Skill definition (canonical)
├── scripts/
│   ├── install_pkg.sh     # phonefast binary installer (bootstrapper)
│   └── replace_pkg.sh     # phonefast binary replacer (local build swap)
├── references/
│   └── architecture.md    # phonefast internals (progressive disclosure)
├── evals/
│   └── evals.json         # Test cases for skill evaluation
├── skills-lock.json       # Registry lock for skills.sh
└── README.md
```

## Usage

This skill is loaded automatically when Claude detects an Android/phone automation request. It will:

1. Check device connection via `adb`
2. Ensure `phonefast` daemon is installed and running
3. Observe the screen (screenshot + UI elements)
4. Execute the requested action
5. Confirm the result

## Installing phonefast manually

```bash
bash <(curl -sfL https://raw.githubusercontent.com/gezihua123/phonefast/master/scripts/install_pkg.sh)
```

This installs to `~/.local/bin` by default (no sudo). Use `--global` for `/usr/local/bin`.

## Links

- [phonefast repository](https://github.com/gezihua123/phonefast) — the Go daemon that powers this skill
- [phonefast benchmarks](https://github.com/gezihua123/phonefast/blob/master/phonefast.md) — performance comparison vs raw ADB
