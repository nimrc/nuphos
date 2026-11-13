# The fork's omp (omp.sh) runtime: the published runtime image with omp in place of OpenCode,
# bound to Yu AI's deepseek-v4.1-flash through the backend's /llm/yuai/v1, which bills each turn
# to its user's own Yu AI key. Build with apps/runtime as the context; see docs/yuai.md.
ARG BASE=ghcr.io/nuphos/runtime:0.1.55-opencode
FROM ${BASE}
ARG OMP_VERSION=18.20.0

USER root
RUN set -eux; cd /tmp; \
    base="https://github.com/can1357/oh-my-pi/releases/download/v${OMP_VERSION}"; \
    curl -fsSLO "${base}/omp-linux-x64"; curl -fsSLO "${base}/SHA256SUMS.txt"; \
    grep " omp-linux-x64$" SHA256SUMS.txt | sha256sum -c -; \
    install -m 755 omp-linux-x64 /usr/local/bin/omp; rm -f omp-linux-x64 SHA256SUMS.txt; \
    omp --version
# The fork's shim knows omp and seeds its settings from these templates on every start.
COPY image/acp-shim.mjs /opt/acp-shim.mjs
COPY yuai-omp/models.yml yuai-omp/config.yml /etc/nuphos-runtime/omp/
# Nothing to sign in to: the runtime always reports itself signed in and offers no sign-in.
# No OpenCode download on first start either.
ENV OPENAB_AGENT_COMMAND="node /opt/acp-shim.mjs omp" \
    OPENAB_ADAPTER_VERSION="omp@${OMP_VERSION}" \
    NUPHOS_RUNTIME_PREINSTALL="" \
    OPENAB_RUNTIME_AUTH_COMMAND="echo true" \
    OPENAB_AGENT_AUTH_COMMAND="" \
    OPENAB_RUNTIME_LOGIN_COMMAND="" \
    OPENAB_RUNTIME_AUTH_FILE=""
USER node
