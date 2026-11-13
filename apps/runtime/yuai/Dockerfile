# The fork's OpenCode runtime: the published image with one model, Yu AI's deepseek-v4.1-flash,
# reached through the backend's /llm/yuai/v1, which bills each turn to its user's own Yu AI key.
# Build from this directory; see docs/yuai.md.
ARG BASE=ghcr.io/nuphos/runtime:0.1.55-opencode
FROM ${BASE}

USER root
COPY opencode.json /etc/opencode/opencode.json
# OPENCODE_CONFIG adds this file to OpenCode's global config; enabled_providers keeps every other
# provider out. Nothing to sign in to, so the runtime always reports itself signed in, and no
# sign-in command is offered.
ENV OPENCODE_CONFIG=/etc/opencode/opencode.json \
    OPENAB_RUNTIME_AUTH_COMMAND="echo true" \
    OPENAB_AGENT_AUTH_COMMAND="" \
    OPENAB_RUNTIME_LOGIN_COMMAND="" \
    OPENAB_RUNTIME_AUTH_FILE=""
USER node
