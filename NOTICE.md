# Notice

BF-Agent-Ledger started as a copy of the Agents plugin that ships with
[Omarchy](https://github.com/omacom/omarchy) (`shell/plugins/agents`), which is
MIT licensed, copyright David Heinemeier Hansson. `Agent.qml`, the data
loading and sync code in `Main.qml`, the limit rows and the overall shape of
`Panel.qml` come from it. Everything else was written for this plugin.

Limits for Claude Code, Codex and Fireworks are produced by Omarchy's own
collectors, which this plugin runs but does not include.

The log adapters in `bin/usage-index` were written for this plugin. Where an
agent's format had to be learned, it was learned from that agent's own source
or documentation — [OpenCode](https://github.com/anomalyco/opencode),
[Pi](https://github.com/earendil-works/pi),
[Hermes](https://github.com/NousResearch/hermes-agent),
[Gemini CLI](https://github.com/google-gemini/gemini-cli),
[Grok Build](https://github.com/xai-org/grok-build) and
[Kigi](https://github.com/BeforeUgone123/Kigi-CLI), a fork of it — and from how other
MIT-licensed Omarchy plugins read the same files, with thanks to their authors:
[omarchy-agent-collectors](https://github.com/rohaquinlop/omarchy-agent-collectors),
[n0d3x.agents](https://github.com/n0d3xt-max/n0d3x.agents),
[omarchy-agents-usage](https://github.com/Murali-lns/omarchy-agents-usage),
[omarchy-grok-usage](https://github.com/calmasacow/omarchy-grok-usage) and
[omarchy-hermes-usage](https://github.com/r0b0tlab/omarchy-hermes-usage).
No code was copied from them.

The marks in `assets/` identify the services whose usage is shown. They are
trademarks of their owners — Anthropic, OpenAI, Cognition, Moonshot AI and
Fireworks AI — and are not covered by this plugin's license. The Kimi mark is
used under the license in `assets/kimi.LICENSE`; the Kigi mark is the Kigi
project's own.

Prices in `pricing.json` are copied from each provider's public price page,
named in that file.
