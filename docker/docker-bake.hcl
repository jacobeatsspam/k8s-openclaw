variable "OPENCLAW_REF" {}

group "default" {
  targets = ["docker-openclaw"]
}

target "openclaw-upstream" {
  context    = "https://github.com/openclaw/openclaw.git#${OPENCLAW_REF}"
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64"]
  args = {
    OPENCLAW_EXTENSIONS                = "diffs,lobster,google-meet"
    OPENCLAW_IMAGE_APT_PACKAGES        = "bash build-essential ca-certificates ccache chromium clang-tools cmake curl dnsutils ffmpeg fonts-liberation fonts-noto-color-emoji gh git gnupg hostname iproute2 iputils-ping jq libsqlite3-dev lsof make novnc openssh-client openssl pipx procps ripgrep rsync socat tmux unzip websockify x11vnc xvfb"
    OPENCLAW_INSTALL_BROWSER           = "1"
    OPENCLAW_INSTALL_DOCKER_CLI        = "1"
    OPENCLAW_DOCKER_BUILD_NODE_OPTIONS = "--max-old-space-size=8192"
    OPENCLAW_DOCKER_BUILD_SKIP_DTS     = "1"
  }
}

target "docker-openclaw" {
  context    = "docker"
  dockerfile = "upstream-overlay.Dockerfile"
  contexts = {
    upstream = "target:openclaw-upstream"
  }
  platforms = ["linux/amd64"]
}
