# Integrations

PaglaMLX can automatically configure third-party tools to use the local gateway. Open **Settings → Integrations** and click **Apply** on any target.

## VS Code extensions

All VS Code extensions share the same settings file (`~/Library/Application Support/Code/User/settings.json`). A single Apply configures all of them:

| Extension       | What's configured                                         |
|-----------------|-----------------------------------------------------------|
| GitHub Copilot  | `github.copilot.advanced.debug.overrideProxyUrl`          |
| Kilo Code       | `apiBase` + `apiKey`                                      |
| Open Code       | `apiBase` + `apiKey`                                      |
| Cline           | `apiBase` + `apiKey`                                      |
| Claude Code     | `claude-code.apiBase` + `claude-code.apiKey`              |

## Standalone tools

| Tool           | Config file                              | What's configured                        |
|----------------|------------------------------------------|------------------------------------------|
| Continue.dev   | `~/.continue/config.json`                | OpenAI provider pointing to `PaglaMLX` model |
| Claude Code    | `~/.claude.json`                         | `customApiEndpoints.pagla` block        |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `ANTHROPIC_BASE_URL` + `ANTHROPIC_API_KEY` env vars |
| OpenCode       | `~/.config/opencode/opencode.json`       | Provider block (`@ai-sdk/openai-compatible`) |
| Codex CLI      | `~/.codex/config.toml`                   | Full TOML provider config                 |

## Other tools

| Tool          | Config file                | What's configured |
|---------------|----------------------------|-------------------|
| Agent Hermes  | `~/.hermes/config.json`    | `apiBase` + `apiKey` |
| OpenClaw      | `~/.openclaw/config.json`  | `apiBase` + `apiKey` |
| Qwen Code     | `~/.qwen/config.json`      | `apiBase` + `apiKey` |

The Apply button writes a backup of the original config before making changes (`.bak`). To revert, restore the backup file or click Apply again with the gateway stopped.
