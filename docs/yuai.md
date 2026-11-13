# Yu AI fork notes

This fork (github.com/nimrc/nuphos, branch `feat/logto-sso`) runs Nuphos for Yu AI users at
https://nuphos.yuai.dev. What it adds on top of upstream:

- **Sign-in through any OpenID Connect provider** (Logto at auth.yuai.dev): `OIDC_*` env,
  Desktop and iOS buttons, and `/auth/social/device` to approve `nuphos login` codes.
- **Cloud runtimes bound to Yu AI**: OpenCode only (`NUPHOS_RUNTIME_PROVIDERS=opencode`), on the
  image built from `apps/runtime/yuai` (`CLAUDE_CODE_RUNTIME_IMAGES=opencode=<image>`), with one
  model, `deepseek-v4.1-flash`. OpenCode calls `$NUPHOS_BACKEND_URL/llm/yuai/v1` with its
  session token; the backend finds the paying user (the sender of a human turn, the conversation
  owner otherwise), looks up that user's own Yu AI key through sub2api's admin API by email
  (`YUAI_ADMIN_KEY`; a key named `YUAI_KEY_NAME`, default `nuphos`, wins) and forwards the call.
- **One runtime per team, no setup step**: with `NUPHOS_DEFAULT_RUNTIME=opencode` a team gets its
  OpenCode cloud runtime (owned by the team owner) the first time its runtimes are listed; once per
  team, so one deleted on purpose is not recreated. `NUPHOS_RUNTIME_PROVIDERS` also filters the
  runtime list (members' own computers included), so other providers can be neither seen nor
  chatted on.
- **Helm**: `oidc.*`, `backend.imagePullSecrets`, and `provisioner.*` (ServiceAccount, RBAC and
  NetworkPolicy for cloud runtimes).

## Building the runtime image

```sh
docker build -t <registry>/nuphos-runtime:opencode-yuai-<n> apps/runtime/yuai
docker push <registry>/nuphos-runtime:opencode-yuai-<n>
```

`BASE` picks the published OpenCode runtime it builds on.

## TODO

- **Session token lifetime.** The token OpenCode sends is minted per turn and expires after 24h,
  but OpenCode reads `{env:NUPHOS_TOKEN}` once, when acp-shim starts it for a session. An OpenCode
  process kept alive past 24h would get 401 from `/llm/yuai`. Check whether acp-shim respawns
  OpenCode with each turn's env; if not, read the token per request (e.g. a header from a file
  under `$OPENAB_CREDENTIALS_DIR`, as `runtime-guard.sh` does) or accept recently expired tokens
  for this route only.
