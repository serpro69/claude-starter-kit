# Task ID: 12

**Title:** Portable Memory — rclone Sync Configuration

**Status:** pending

**Dependencies:** 10

**Priority:** medium

**Description:** Configure rclone bidirectional sync on both machines with unconditional health data exclusions.

**Details:**

Mac Pro: install rclone, configure gdrive remote via OAuth. Write /usr/local/bin/openclaw-sync.sh: rclone bisync ~/.openclaw/workspace gdrive:openclaw-workspace with hardcoded --exclude health/**, health/memory/**, *.tmp, .git/**; --conflict-loser delete; --resilient; log to /var/log/openclaw/sync.log. Write systemd timer openclaw-sync.timer (OnUnitActiveSec=300). Enable timer. VPS: rclone.conf provided via Docker volume mount from config/rclone.conf. VPS sync container already configured in docker-compose.yml. Add nightly Mac Pro cron: 03:00 ingest personal_notes, 03:05 ingest health_records (local-only ingest, never synced).

**Test Strategy:**

Create test note in notes/ on Mac — appears in Drive within 5min and VPS within 10min. Create file in health/ — does NOT appear in Drive after 5min, does NOT appear on VPS. grep health /var/log/openclaw/sync.log shows only exclusion lines, not transfer lines.
