# Yu AI fork notes

This fork (github.com/nimrc/nuphos, branch `feat/logto-sso`) runs Nuphos for Yu AI users at
https://nuphos.yuai.dev. What it adds on top of upstream:

- **Sign-in through any OpenID Connect provider** (Logto at auth.yuai.dev): `OIDC_*` env,
  Desktop and iOS buttons, and `/auth/social/device` to approve `nuphos login` codes.
- **Cloud runtimes bound to Yu AI**: omp (omp.sh, `omp acp`) is a provider of its own, `omp`, and
  the deployment offers it alone (`NUPHOS_RUNTIME_PROVIDERS=omp`), on the image built from
  `apps/runtime/yuai-omp` (`CLAUDE_CODE_RUNTIME_IMAGES=omp=<image>`), with one model,
  `deepseek-v4.1-flash`. acp-shim writes `~/.omp/agent/{models,config}.yml` from the image's
  templates in `/etc/nuphos-runtime/omp/` on every start, filling in the session's
  `NUPHOS_BACKEND_URL`. The OpenCode variant (`apps/runtime/yuai`) still builds; omp idles at about
  a fifth of OpenCode's memory. OpenCode calls `$NUPHOS_BACKEND_URL/llm/yuai/v1` with its
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

## Building the runtime images

```sh
# omp (the one deployed): context is apps/runtime, for the shim
docker build -f apps/runtime/yuai-omp/Dockerfile -t <registry>/nuphos-runtime:omp-yuai-<n> apps/runtime
# OpenCode
docker build -t <registry>/nuphos-runtime:opencode-yuai-<n> apps/runtime/yuai
```

`BASE` picks the published runtime image they build on; `OMP_VERSION` the omp release.

## TODO

- **Session token lifetime.** The token omp/OpenCode send is minted per turn and expires after 24h,
  but the agent reads `NUPHOS_TOKEN` from the env acp-shim started it with. An agent
  process kept alive past 24h would get 401 from `/llm/yuai`. Check whether acp-shim respawns
  OpenCode with each turn's env; if not, read the token per request (e.g. a header from a file
  under `$OPENAB_CREDENTIALS_DIR`, as `runtime-guard.sh` does) or accept recently expired tokens
  for this route only.
