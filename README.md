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

Requires [Clams CLI](https://clams.tech) installed and accessible on your `PATH`.

### User-level (all projects)

```bash
git clone https://github.com/clams-tech/agent-skills.git
cp -r agent-skills/clams ~/.agents/skills/clams
```

Or for Claude Code specifically:

```bash
cp -r agent-skills/clams ~/.claude/skills/clams
```

### Project-level (single repo)

```bash
cp -r agent-skills/clams .agents/skills/clams
```

The `~/.agents/skills/` path is the [cross-client convention](https://agentskills.io/client-implementation/adding-skills-support) — any agent that supports the Agent Skills spec will discover it there.

## Privacy

This skill sends your prompts and Clams CLI output to whichever AI model your agent is connected to. If you are running a hosted model (Claude, GPT, etc.), your financial data — balances, transaction history, cost basis, gains — will leave your machine.

**Do not use this skill with a hosted model if you are not comfortable with that.**

You can run this skill with a local model (Ollama, llama.cpp, etc.) to keep everything on your machine, but in our testing local models struggle with the multi-step workflows and produce significantly worse results. The skill was designed for and tested against frontier models.

## Eval Results

We tested the skill against 5 real-world prompts, each with a set of assertions checked programmatically. Every eval was run with and without the skill installed (Claude Opus 4.6, single run per eval).

| # | Eval | With Skill | Without Skill |
|---|------|-----------|---------------|
| 1 | **Onboarding + xpub wallet** — full setup from scratch, connect a Coldcard xpub, sync, show balance | 10/10 (100%) | 6/10 (60%) |
| 2 | **Capital gains PDF** — generate a 2025 capital gains report as a branded PDF | 5/5 (100%) | 3/5 (60%) |
| 3 | **Multi-connection portfolio** — connect xpub + LND + Phoenix CSV, show consolidated portfolio in USD | 8/8 (100%) | 6/8 (75%) |
| 4 | **Tax season reports** — capital gains PDF + journal entries CSV + balance sheet PDF in one go | 6/6 (100%) | 4/6 (67%) |
| 5 | **Custom CSV import** — map an unsupported exchange CSV to Clams via csv_mapping and import it | 8/8 (100%) | 6/8 (75%) |

**With skill: 100% pass rate across all 37 assertions.** Without skill: 67% average.

The skill also made the agent faster (57s avg vs 80s) and cheaper (20k tokens avg vs 25k) because it didn't waste time guessing CLI flags or writing workaround scripts.

Common failure modes without the skill: using `clams init` (interactive, hangs), not using `--machine --format json`, not knowing about the bundled render scripts, skipping `clams rates sync`, and not knowing csv_mapping exists.

## Spec

This skill follows the [Agent Skills](https://agentskills.io) open standard. It works with any agent that supports the `SKILL.md` format, including Claude Code, Codex and Opencode.

## License

MIT
