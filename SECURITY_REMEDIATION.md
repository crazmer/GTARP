# BotRP Main v2.0 Security & Enhanced Remediation

## Baseline

Main v2.0 commit: `743d6aafb948e100d861610aa7e0922e433a0c9f`.

## Confirmed items

1. Live server credentials are present in `txData/Qbox_A4B177.base/server.cfg`. Rotate the affected credentials and move them to deployment-time secrets before production use.
2. The startup configuration contains `sv_enforceGameBuild 3258`, and the 2026-09-12 startup log reports that value as invalid for the running artifact.
3. The startup configuration ensures `sessionmanager` and `hardcap`, while the 2026-09-12 startup log reports both resources as not found.
4. The startup configuration ensures `[assets]`, while the repository resource-group listing does not contain an `[assets]` group.
5. Renewed-Banking transaction callbacks accept client-provided account identifiers; authorization of organization/shared accounts must be enforced server-side before account debits or credits.

## Safe operator actions

- Rotate the exposed FiveM license key.
- Change the exposed database password and avoid using a privileged database account for normal server operation.
- Provide the new secrets through an untracked deployment-local configuration mechanism.
- Do not re-add `sv_enforceGameBuild 3258` unless it is confirmed valid for the exact Enhanced artifact being used.
- Do not add replacement copies of `sessionmanager` or `hardcap` until the artifact/resource package is verified.
- Add the intended Enhanced asset group only when its contents are present and tested.

## Runtime gate

After remediation, perform a clean Enhanced boot and verify:

- no startup errors for missing resources;
- valid game build configuration;
- database connectivity;
- Qbox/OX initialization;
- NPWD initialization;
- voice initialization;
- banking callbacks and account authorization;
- appearance persistence;
- vehicle persistence/keys;
- weather/time synchronization.
