# Auth Refactor — Design

## Overview

Replace the legacy session-based auth middleware with JWT-based authentication. The current middleware stores session tokens in a way that does not meet compliance requirements for token storage.

## Problem Statement

The existing auth middleware persists session tokens in plaintext cookies. Legal flagged this as non-compliant with the updated data handling policy. The middleware must be replaced with a stateless JWT approach that keeps tokens out of persistent storage.

## Goals

1. Replace session-based auth with JWT tokens (access + refresh)
2. Zero-downtime migration — both auth methods work during transition
3. All existing protected endpoints continue to work without client changes

## Non-Goals

1. OAuth/social login integration — separate feature
2. API rate limiting — not auth-related

## Architecture

### Token Flow

Login endpoint issues a short-lived access token (15min) and a longer-lived refresh token (7d). Access token is sent in Authorization header. Refresh token is sent as an httpOnly cookie. Middleware validates the access token on each request; on expiry, the client hits the refresh endpoint.

### Migration Strategy

Dual-middleware phase: both session and JWT middleware active. New endpoints issue JWT. Old sessions remain valid until they expire (max 24h). After 24h, remove session middleware.

## Assumptions

- All clients can be updated to send Authorization headers within the migration window.
- The refresh token rotation approach (one-time use) is acceptable for the expected session concurrency.

## Not Doing

- **Token revocation list** — adds complexity; short-lived access tokens and refresh rotation are sufficient for the compliance requirement.
- **Multi-device session management** — out of scope; each device gets independent tokens.
