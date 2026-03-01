# Task ID: 3

**Title:** OpenClaw Dockerfile (VPS)

**Status:** pending

**Dependencies:** 2

**Priority:** high

**Description:** Write Dockerfile.openclaw for the VPS OpenClaw gateway image.

**Details:**

Base image: debian:bookworm-slim. Install curl and ca-certificates. Install OpenClaw binary via official install script. Create /root/.openclaw/workspace directory. EXPOSE 18789. ENTRYPOINT ["openclaw", "start", "--foreground"]. Minimal image — no dev tools. Label with version and build date.

**Test Strategy:**

docker build completes without error. openclaw --version prints a version string. Image size under 200MB.
