# BotRP

BotRP is the custom roleplay layer built on the existing Qbox server stack.

## Foundation principles

- Keep custom systems in separate `botrp_*` resources.
- Do not modify Qbox core unless a compatibility patch is unavoidable.
- Prefer exports/events over tight gameplay-resource coupling.
- Keep database ownership explicit for every custom resource.
- Treat the currently working Qbox + NPWD setup as the baseline.
- Hosting/network-provider troubleshooting is outside this foundation checkpoint.

## Planned resource layout

```text
resources/
├── [qbx]/
├── [ox]/
├── [npwd]/
├── [voice]/
├── [botrp]/
│   ├── botrp_core/
│   ├── botrp_identity/
│   ├── botrp_admin/
│   ├── botrp_logging/
│   └── botrp_utils/
└── [botrp-apps]/
```

## Current baseline

- Framework: Qbox
- Inventory: ox_inventory
- Database: oxmysql
- Phone: NPWD + qbx_npwd
- Voice: pma-voice

NPWD is considered operational and is intentionally not modified by the BotRP foundation work.

## Development rule

BotRP resources should depend on public Qbox/OX APIs where possible and should not copy or fork framework-owned data unnecessarily.
