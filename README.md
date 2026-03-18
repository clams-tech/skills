# Clams Agent Skills

An [Agent Skill](https://agentskills.io) that teaches AI coding agents how to use [Clams](https://clams.tech) — the open-source Bitcoin accounting tool.

When installed, the skill gives your agent the knowledge to:

- Set up workspaces, profiles, and connections (xpub, Lightning, custodial)
- Sync on-chain and off-chain transaction history
- Process journals and generate reports (balance sheet, portfolio summary, capital gains)
- Render branded PDF and CSV exports
- Import custom CSV files from unsupported exchanges
- Manage cost basis tracking with configurable algorithms (FIFO, LIFO, HIFO, etc.)

## Installation

Copy the `clams/` directory into your agent's skills folder. For Claude Code:

```bash
cp -r clams/ ~/.claude/skills/clams
```

Or add it as a project-level skill:

```bash
cp -r clams/ .claude/skills/clams
```

The skill triggers automatically when your prompt mentions Bitcoin accounting, cost basis, tax reports, portfolio balances, or related topics — even without mentioning "Clams" by name.

## Privacy

This skill sends your prompts and Clams CLI output to whichever AI model your agent is connected to. If you are running a hosted model (Claude, GPT, etc.), your financial data — balances, transaction history, cost basis, gains — will leave your machine.

**Do not use this skill with a hosted model if you are not comfortable with that.**

If privacy is a concern, use this skill with a local model running entirely on your hardware (e.g. via Ollama, llama.cpp, or similar). With a local model, nothing leaves your machine.

## Spec

This skill follows the [Agent Skills](https://agentskills.io) open standard. It works with any agent that supports the `SKILL.md` format, including Claude Code, Codex CLI, and ChatGPT.

## License

MIT
