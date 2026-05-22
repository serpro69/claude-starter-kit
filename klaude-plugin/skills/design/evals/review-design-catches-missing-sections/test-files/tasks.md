# Tasks: Notification System

> Design: [./design.md](./design.md)
> Implementation: [./implementation.md](./implementation.md)
> Status: pending
> Created: 2026-05-01

## Task 1: Create all database models
- **Status:** pending
- **Depends on:** —

### Subtasks
- [ ] 1.1 Create `notifications` table migration
- [ ] 1.2 Create `notification_preferences` table migration
- [ ] 1.3 Create model structs for both tables

## Task 2: Build all API endpoints
- **Status:** pending
- **Depends on:** Task 1

### Subtasks
- [ ] 2.1 GET /api/notifications — list notifications for current user
- [ ] 2.2 POST /api/notifications/:id/read — mark as read
- [ ] 2.3 GET /api/notification-preferences — get user preferences
- [ ] 2.4 PUT /api/notification-preferences — update preferences

## Task 3: Implement email sending
- **Status:** pending
- **Depends on:** Task 1

### Subtasks
- [ ] 3.1 Create NotificationService with email dispatch
- [ ] 3.2 Create email templates
- [ ] 3.3 Wire comment creation event to NotificationService

## Task 4: Build frontend notification UI
- **Status:** pending
- **Depends on:** Task 2

### Subtasks
- [ ] 4.1 Add notification bell icon with unread badge
- [ ] 4.2 Create notification dropdown panel
- [ ] 4.3 Add polling for unread count
- [ ] 4.4 Create notification preferences page

## Task 5: Final verification
- **Status:** pending
- **Depends on:** Task 1, Task 2, Task 3, Task 4

### Subtasks
- [ ] 5.1 Run full test suite
- [ ] 5.2 Review code
