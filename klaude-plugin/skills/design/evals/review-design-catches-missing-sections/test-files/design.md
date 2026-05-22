# Notification System — Design

## Overview

Add email and in-app notifications when users receive comments on their posts.

## Problem Statement

Users currently have no way to know when someone comments on their post unless they manually check. This leads to missed conversations and low engagement.

## Goals

1. Send email notifications for new comments
2. Show in-app notification badges
3. Allow users to configure notification preferences

## Architecture

### Email Service

Use the existing SMTP gateway. Create a `NotificationService` that accepts events and dispatches emails via the gateway. Template emails using the existing templating engine.

### In-App Notifications

Store notifications in a `notifications` table. Poll every 30 seconds from the frontend for unread count. Mark as read when the user opens the notification panel.

### Preferences

Add a `notification_preferences` table with per-user, per-channel toggles. Default all channels to enabled.
