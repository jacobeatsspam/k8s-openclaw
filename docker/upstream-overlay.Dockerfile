FROM upstream

SHELL ["/bin/bash", "-c"]

USER root
ENV SHELL="/bin/bash"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint

RUN set -exuo pipefail \
	&& chmod 0755 /usr/local/bin/docker-entrypoint

RUN set -exuo pipefail \
	&& curl -SLo /usr/local/bin/kubectl https://dl.k8s.io/release/v1.36.2/bin/linux/amd64/kubectl \
	&& chmod 0755 /usr/local/bin/kubectl

RUN set -exuo pipefail \
	&& curl -SLo /usr/local/bin/tea https://dl.gitea.com/tea/v0.10.1/tea-v0.10.1-linux-amd64 \
	&& chmod 755 /usr/local/bin/tea

RUN set -exuo pipefail \
	&& arch="$(dpkg --print-architecture)" \
	&& case "$arch" in \
		amd64) rtk_target='x86_64-unknown-linux-musl' ;; \
		arm64) rtk_target='aarch64-unknown-linux-gnu' ;; \
		*) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
	esac \
	&& tmpdir="$(mktemp -d)" \
	&& cd "$tmpdir" \
	&& rtk_asset="rtk-${rtk_target}.tar.gz" \
	&& curl -fsSLO "https://github.com/rtk-ai/rtk/releases/download/v0.44.1/${rtk_asset}" \
	&& curl -fsSLO "https://github.com/rtk-ai/rtk/releases/download/v0.44.1/checksums.txt" \
	&& grep "  ${rtk_asset}$" checksums.txt | sha256sum -c - \
	&& tar -xzf "$rtk_asset" rtk \
	&& install -m 0755 rtk /usr/local/bin/rtk \
	&& cd / \
	&& rm -rf "$tmpdir"

# Install standalone CLI binaries needed by bundled OpenClaw skills without
# depending on Homebrew inside the container image.
RUN set -exuo pipefail \
	&& arch="$(dpkg --print-architecture)" \
	&& case "$arch" in \
		amd64) release_arch='linux_amd64' ;; \
		arm64) release_arch='linux_arm64' ;; \
		*) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
	esac \
	&& tmpdir="$(mktemp -d)" \
	&& cd "$tmpdir" \
	&& gog_asset="gogcli_0.34.1_${release_arch}.tar.gz" \
	&& curl -fsSLO "https://github.com/openclaw/gogcli/releases/download/v0.34.1/${gog_asset}" \
	&& curl -fsSLO "https://github.com/openclaw/gogcli/releases/download/v0.34.1/checksums.txt" \
	&& grep "  ${gog_asset}$" checksums.txt | sha256sum -c - \
	&& tar -xzf "$gog_asset" gog \
	&& install -m 0755 gog /usr/local/bin/gog \
	&& rm -f "$gog_asset" checksums.txt gog \
	&& wacli_asset="wacli_0.13.0_${release_arch}.tar.gz" \
	&& curl -fsSLO "https://github.com/openclaw/wacli/releases/download/v0.13.0/${wacli_asset}" \
	&& curl -fsSLO "https://github.com/openclaw/wacli/releases/download/v0.13.0/checksums.txt" \
	&& grep "  ${wacli_asset}$" checksums.txt | sha256sum -c - \
	&& tar -xzf "$wacli_asset" wacli \
	&& install -m 0755 wacli /usr/local/bin/wacli \
	&& cd / \
	&& rm -rf "$tmpdir"

# Keep Bun and Go available at runtime for skills and agent workflows.
RUN set -exuo pipefail \
	&& export GOROOT='/usr/local/src/go' GOPATH='/usr/local/go' GOBIN='/usr/local/bin' \
	&& bash <(curl -sL https://git.io/go-installer) \
	&& mv "${GOROOT}/bin/go" "${GOBIN}/go" \
	&& mv "${GOROOT}/bin/gofmt" "${GOBIN}/gofmt" \
	&& rmdir "${GOROOT}/bin" "${GOPATH}/bin" \
	&& BUN_INSTALL='/usr/local' SHELL='NOSHELL' \
		bash <(curl --retry 5 --retry-all-errors --retry-delay 2 -fsSL https://bun.sh/install)

RUN set -exuo pipefail \
	&& install -d -o node -g node -m 0775 \
		/home/node/.local/bin \
		/home/node/.local/share/pnpm \
		/home/node/.local/share/pnpm/store \
		/home/node/.local/share/pnpm/global \
	&& chown -R node:node /home/node

USER node
ENV HOME="/home/node"
ENV GOROOT="/usr/local/src/go"
ENV GOPATH="${HOME}/go"
ENV GOBIN="${GOPATH}/bin"
ENV PATH="${HOME}/.local/bin:${GOBIN}:${PATH}"
ENV NODE_LLAMA_CPP_CMAKE_OPTION_GGML_CUDA=OFF
ENV NODE_LLAMA_CPP_CMAKE_OPTION_GGML_HIP=OFF
ENV NODE_LLAMA_CPP_CMAKE_OPTION_GGML_VULKAN=OFF
ENV NODE_LLAMA_CPP_GPU="false"
ENV OPENCLAW_PREFER_PNPM=1

WORKDIR "${HOME}"

RUN set -exuo pipefail \
	&& touch "${HOME}/.bashrc" \
	&& mkdir -p "${HOME}/.local/bin" \
	&& echo 'export GOROOT="/usr/local/src/go"' >> "${HOME}/.bashrc" \
	&& echo 'export GOPATH="${HOME}/go"' >> "${HOME}/.bashrc" \
	&& echo 'export GOBIN="${GOPATH}/bin"' >> "${HOME}/.bashrc" \
	&& echo 'export PATH="${HOME}/.local/bin:${GOBIN}:${PATH}"' >> "${HOME}/.bashrc"

RUN set -exuo pipefail \
	&& go install golang.org/x/tools/cmd/goimports@latest \
	&& go install golang.org/x/tools/gopls@latest \
	&& go install github.com/steipete/songsee/cmd/songsee@latest \
	&& go install github.com/steipete/gifgrep/cmd/gifgrep@latest \
	&& go install github.com/steipete/goplaces/cmd/goplaces@latest

RUN set -exuo pipefail \
	&& pnpm config set package-import-method copy \
	&& pnpm config set global-bin-dir "${HOME}/.local/bin" \
	&& pnpm install -g --child-concurrency=1 --allow-build=better-sqlite3 --allow-build=node-llama-cpp @tobilu/qmd \
	&& pnpm install -g --child-concurrency=1 --allow-build=protobufjs @steipete/summarize \
	&& pnpm install -g --child-concurrency=1 clawhub \
	&& pnpm install -g --child-concurrency=1 @google/gemini-cli

RUN set -exuo pipefail \
	&& pipx install "git+https://github.com/truenas/api_client.git@TS-25.10.3" \
	&& pipx install openai-whisper

WORKDIR /app

RUN set -exuo pipefail \
	&& tmpdir="$(mktemp -d)" \
	&& curl -fsSL "https://codeload.github.com/rtk-ai/rtk/tar.gz/refs/tags/v0.44.1" -o "$tmpdir/rtk.tar.gz" \
	&& tar -xzf "$tmpdir/rtk.tar.gz" -C "$tmpdir" \
	&& cp -r "$tmpdir/rtk-0.44.1/openclaw" /app/extensions/rtk-rewrite \
	&& jq '.openclaw.extensions=["./index.ts"]' "$tmpdir/rtk-0.44.1/openclaw/package.json" > /app/extensions/rtk-rewrite/package.json \
	&& cp -r /app/extensions/rtk-rewrite /app/dist/extensions/rtk-rewrite \
	&& bun build /app/dist/extensions/rtk-rewrite/index.ts --target=node --outfile=/app/dist/extensions/rtk-rewrite/index.js \
	&& rm /app/dist/extensions/rtk-rewrite/index.ts \
	&& rm -rf "$tmpdir"

RUN set -exuo pipefail \
	&& node openclaw.mjs plugins install @openclaw/codex \
	&& node openclaw.mjs plugins install clawhub:@openclaw/whatsapp \
	&& node openclaw.mjs plugins install @openclaw/searxng-plugin \
	&& node openclaw.mjs plugins install @openclaw/nextcloud-talk

EXPOSE 18789
EXPOSE 9222 5900 6080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
CMD ["--allow-unconfigured"]
