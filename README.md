# Clams Agent Skills

An [Agent Skill](https://agentskills.io) that teaches AI coding agents how to use [Clams](https://clams.tech)

When installed, the skill gives your agent the knowledge to:

- Set up workspaces, profiles, and connections (xpub, Lightning, custodial)
- Sync on-chain and off-chain transaction history
- Process journals and generate reports (balance sheet, portfolio summary, capital gains)
- Render branded PDF and CSV exports
- Import custom CSV files from unsupported wallets / exchanges
- Manage cost basis tracking with configurable algorithms (FIFO, LIFO, HIFO, etc.)

## Installation

@TODO

## Privacy

This skill sends your prompts and Clams CLI output to whichever AI model your agent is connected to. If you are running a hosted model (Claude, GPT, etc.), your financial data — balances, transaction history, cost basis, gains — will leave your machine.

**Do not use this skill with a hosted model if you are not comfortable with that.**

If privacy is a concern, use this skill with a local model running entirely on your hardware (e.g. via Ollama, llama.cpp, or similar). With a local model, nothing leaves your machine. NOTE - the performance will be a lot slower and will make a lot more mistakes. We have tested.

## Spec

This skill follows the [Agent Skills](https://agentskills.io) open standard. It works with any agent that supports the `SKILL.md` format, including Claude Code, Codex and Opencode.

## License

MIT
