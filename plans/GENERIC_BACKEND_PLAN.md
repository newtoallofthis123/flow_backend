# FLOW CRM - Generic Backend Implementation Plan

**Version:** 1.0
**Date:** November 11, 2025
**Scope:** Core functionality - Database schemas, relations, and API routes

---

## Overview

This plan outlines a framework-agnostic backend architecture for the Flow CRM application. It focuses on:
- Database schema design with proper relations
- RESTful API route structure
- Naming conventions and standards
- Data integrity and performance considerations

**Note:** This plan is generic and not specific to any framework. A Phoenix/Elixir-specific implementation plan will follow after approval.

---

## Naming Conventions

### Database Tables
- **Plural snake_case**: `users`, `contacts`, `deals`, `calendar_events`
- **Join tables**: `entity1_entity2` (e.g., `deals_tags`, `contacts_tags`)

### Database Fields
- **snake_case**: `first_name`, `created_at`, `health_score`
- **Primary keys**: `id` (UUID/integer)
- **Foreign keys**: `entity_id` (e.g., `contact_id`, `user_id`, `deal_id`)
- **Timestamps**: `created_at`, `updated_at`, `deleted_at` (for soft deletes)
- **Booleans**: prefix with `is_` or use descriptive names (e.g., `is_active`, `archived`)

### API Endpoints
- **Plural resources**: `/api/contacts`, `/api/deals`
- **Kebab-case for multi-word**: `/api/calendar-events`, `/api/action-items`
- **Actions as sub-resources**: `POST /api/deals/:id/activities`, `PATCH /api/contacts/:id/communication`

### JSON Response Fields
- **camelCase**: `healthScore`, `firstName`, `createdAt`
- Match frontend TypeScript conventions for seamless integration

---

## Core Entity Relationships

```
users (1) ─────┬─────> (N) contacts
               │
               ├─────> (N) deals
               │
               ├─────> (N) conversations
               │
               ├─────> (N) calendar_events
               │
               └─────> (N) notifications

contacts (1) ──┬─────> (N) deals
               │
               ├─────> (N) communication_events
               │
               ├─────> (N) ai_insights
               │
               └─────> (N) conversations

deals (1) ─────┬─────> (N) deal_activities
               │
               └─────> (N) deal_insights

conversations (1) ───> (N) messages

calendar_events (1) ─┬─> (1) meeting_preparation
                      │
                      ├─> (1) meeting_outcome
                      │
                      └─> (N) meeting_insights

calendar_events (N) ─> (N) attendees (many-to-many via event_attendees)

contacts/deals (N) ───> (N) tags (many-to-many via taggings)
```

---

## Database Schema Design

### 1. Core User Management

#### `users`
```
id                    UUID/BIGINT PRIMARY KEY
email                 VARCHAR(255) UNIQUE NOT NULL
password_hash         VARCHAR(255) NOT NULL
name                  VARCHAR(255) NOT NULL
avatar_url            VARCHAR(500)
role                  ENUM('admin', 'sales', 'manager') DEFAULT 'sales'
theme                 ENUM('light', 'dark') DEFAULT 'light'
notifications_enabled BOOLEAN DEFAULT true
timezone              VARCHAR(50) DEFAULT 'UTC'
last_login_at         TIMESTAMP
created_at            TIMESTAMP NOT NULL
updated_at            TIMESTAMP NOT NULL

INDEXES:
  - email (unique)
  - role
```

#### `sessions` (for JWT refresh tokens)
```
id              UUID/BIGINT PRIMARY KEY
user_id         UUID/BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
refresh_token   VARCHAR(500) NOT NULL UNIQUE
expires_at      TIMESTAMP NOT NULL
created_at      TIMESTAMP NOT NULL

INDEXES:
  - user_id
  - refresh_token (unique)
  - expires_at
```

---

### 2. Contacts Domain

#### `contacts`
```
id                     UUID/BIGINT PRIMARY KEY
user_id                UUID/BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
name                   VARCHAR(255) NOT NULL
email                  VARCHAR(255)
phone                  VARCHAR(50)
company                VARCHAR(255)
title                  VARCHAR(255)
avatar_url             VARCHAR(500)
relationship_health    ENUM('high', 'medium', 'low') DEFAULT 'medium'
health_score           INTEGER DEFAULT 50 CHECK (health_score >= 0 AND health_score <= 100)
last_contact_at        TIMESTAMP
next_follow_up_at      TIMESTAMP
sentiment              ENUM('positive', 'neutral', 'negative') DEFAULT 'neutral'
churn_risk             INTEGER DEFAULT 0 CHECK (churn_risk >= 0 AND churn_risk <= 100)
total_deals_count      INTEGER DEFAULT 0
total_deals_value      DECIMAL(15, 2) DEFAULT 0
notes                  TEXT
created_at             TIMESTAMP NOT NULL
updated_at             TIMESTAMP NOT NULL
deleted_at             TIMESTAMP (soft delete)

INDEXES:
  - user_id
  - health_score DESC
  - churn_risk DESC
  - last_contact_at DESC
  - company, name (for text search)
  - email (for uniqueness per user)

COMPUTED FIELDS (in queries):
  - tags (from taggings)
  - communication_history (from communication_events)
  - ai_insights (from ai_insights table)
```

#### `communication_events`
```
id            UUID/BIGINT PRIMARY KEY
contact_id    UUID/BIGINT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE
user_id       UUID/BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
type          ENUM('email', 'call', 'meeting', 'note') NOT NULL
occurred_at   TIMESTAMP NOT NULL
subject       VARCHAR(500)
summary       TEXT
sentiment     ENUM('positive', 'neutral', 'negative')
ai_analysis   TEXT
created_at    TIMESTAMP NOT NULL
updated_at    TIMESTAMP NOT NULL

INDEXES:
  - contact_id, occurred_at DESC
  - user_id
  - type
  - sentiment
```

---

### 3. Deals Domain

#### `deals`
```
id                   UUID/BIGINT PRIMARY KEY
user_id              UUID/BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
contact_id           UUID/BIGINT NOT NULL REFERENCES contacts(id) ON DELETE SET NULL
title                VARCHAR(255) NOT NULL
company              VARCHAR(255)
value                DECIMAL(15, 2) NOT NULL DEFAULT 0
stage                ENUM('prospect', 'qualified', 'proposal', 'negotiation', 'closed_won', 'closed_lost') DEFAULT 'prospect'
probability          INTEGER DEFAULT 0 CHECK (probability >= 0 AND probability <= 100)
confidence           ENUM('high', 'medium', 'low') DEFAULT 'medium'
expected_close_date  DATE
closed_date          DATE
description          TEXT
priority             ENUM('high', 'medium', 'low') DEFAULT 'medium'
competitor_mentioned VARCHAR(255)
last_activity_at     TIMESTAMP
created_at           TIMESTAMP NOT NULL
updated_at           TIMESTAMP NOT NULL
deleted_at           TIMESTAMP (soft delete)

INDEXES:
  - user_id
  - contact_id
  - stage, probability
  - expected_close_date ASC
  - value DESC
  - last_activity_at DESC
  - priority

COMPUTED FIELDS (in queries):
  - contact_name (from contacts)
  - activities (from deal_activities)
  - insights (from deal_insights)
  - tags (from taggings)
  - risk_factors (from deal_signals where type = 'risk')
  - positive_signals (from deal_signals where type = 'positive')
```

#### `deal_activities`
```
id           UUID/BIGINT PRIMARY KEY
deal_id      UUID/BIGINT NOT NULL REFERENCES deals(id) ON DELETE CASCADE
user_id      UUID/BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
type         ENUM('call', 'email', 'meeting', 'proposal', 'demo', 'note') NOT NULL
occurred_at  TIMESTAMP NOT NULL
description  TEXT NOT NULL
outcome      TEXT
next_step    TEXT
created_at   TIMESTAMP NOT NULL
updated_at   TIMESTAMP NOT NULL

INDEXES:
  - deal_id, occurred_at DESC
  - user_id
  - type
```

#### `deal_signals` (AI-extracted risk factors and positive signals)
```
id          UUID/BIGINT PRIMARY KEY
deal_id     UUID/BIGINT NOT NULL REFERENCES deals(id) ON DELETE CASCADE
type        ENUM('risk', 'positive') NOT NULL
signal      VARCHAR(500) NOT NULL
confidence  INTEGER CHECK (confidence >= 0 AND confidence <= 100)
detected_at TIMESTAMP NOT NULL
created_at  TIMESTAMP NOT NULL

INDEXES:
  - deal_id, type
```

#### `deal_insights`
```
id                UUID/BIGINT PRIMARY KEY
deal_id           UUID/BIGINT NOT NULL REFERENCES deals(id) ON DELETE CASCADE
insight_type      ENUM('opportunity', 'risk', 'suggestion', 'competitor') NOT NULL
title             VARCHAR(255) NOT NULL
description       TEXT NOT NULL
impact            ENUM('high', 'medium', 'low') DEFAULT 'medium'
actionable        BOOLEAN DEFAULT false
suggested_action  TEXT
confidence        INTEGER CHECK (confidence >= 0 AND confidence <= 100)
created_at        TIMESTAMP NOT NULL
updated_at        TIMESTAMP NOT NULL

INDEXES:
  - deal_id, created_at DESC
  - insight_type
  - impact
```

---

### 4. Messages Domain

#### `conversations`
```
id                   UUID/BIGINT PRIMARY KEY
user_id              UUID/BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
contact_id           UUID/BIGINT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE
last_message_at      TIMESTAMP
unread_count         INTEGER DEFAULT 0
overall_sentiment    ENUM('positive', 'neutral', 'negative') DEFAULT 'neutral'
sentiment_trend      ENUM('improving', 'stable', 'declining') DEFAULT 'stable'
ai_summary           TEXT
priority             ENUM('high', 'medium', 'low') DEFAULT 'medium'
archived             BOOLEAN DEFAULT false
created_at           TIMESTAMP NOT NULL
updated_at           TIMESTAMP NOT NULL

INDEXES:
  - user_id, last_message_at DESC
  - contact_id
  - priority, archived
  - unread_count DESC (for unread filtering)

COMPUTED FIELDS (in queries):
  - contact_name (from contacts)
  - contact_company (from contacts)
  - messages (from messages table)
  - tags (from taggings)
```

#### `messages`
```
id               UUID/BIGINT PRIMARY KEY
conversation_id  UUID/BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE
sender_id        UUID/BIGINT REFERENCES users(id) ON DELETE SET NULL
sender_name      VARCHAR(255) NOT NULL
sender_type      ENUM('user', 'contact') NOT NULL
content          TEXT NOT NULL
type             ENUM('email', 'sms', 'chat') DEFAULT 'email'
subject          VARCHAR(500)
sentiment        ENUM('positive', 'neutral', 'negative')
confidence       INTEGER CHECK (confidence >= 0 AND confidence <= 100)
status           ENUM('sent', 'delivered', 'read', 'replied') DEFAULT 'sent'
sent_at          TIMESTAMP NOT NULL
created_at       TIMESTAMP NOT NULL
updated_at       TIMESTAMP NOT NULL

INDEXES:
  - conversation_id, sent_at DESC
  - sender_id
  - sentiment, sent_at
  - status
```

#### `message_analysis` (detailed AI analysis for messages)
```
id                UUID/BIGINT PRIMARY KEY
message_id        UUID/BIGINT NOT NULL REFERENCES messages(id) ON DELETE CASCADE
key_topics        TEXT[] / JSON (array of strings)
emotional_tone    VARCHAR(100)
urgency_level     ENUM('high', 'medium', 'low') DEFAULT 'medium'
business_intent   ENUM('inquiry', 'complaint', 'support', 'purchase', 'follow_up', 'other')
suggested_response TEXT
response_time     VARCHAR(50)
action_items      TEXT[] / JSON (array of strings)
created_at        TIMESTAMP NOT NULL

INDEXES:
  - message_id (unique)
  - urgency_level
  - business_intent
```

#### `attachments`
```
id          UUID/BIGINT PRIMARY KEY
message_id  UUID/BIGINT NOT NULL REFERENCES messages(id) ON DELETE CASCADE
name        VARCHAR(255) NOT NULL
type        VARCHAR(100)
size        BIGINT
storage_url VARCHAR(500) NOT NULL
created_at  TIMESTAMP NOT NULL

INDEXES:
  - message_id
```

#### `message_templates`
```
id          UUID/BIGINT PRIMARY KEY
user_id     UUID/BIGINT REFERENCES users(id) ON DELETE CASCADE (NULL for system templates)
name        VARCHAR(255) NOT NULL
category    ENUM('follow_up', 'meeting', 'proposal', 'support', 'introduction', 'other')
content     TEXT NOT NULL
variables   TEXT[] / JSON (array of variable names like ["firstName", "company"])
is_system   BOOLEAN DEFAULT false
created_at  TIMESTAMP NOT NULL
updated_at  TIMESTAMP NOT NULL

INDEXES:
  - user_id, category
  - is_system
```

---

### 5. Calendar Domain

#### `calendar_events`
```
id               UUID/BIGINT PRIMARY KEY
user_id          UUID/BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
contact_id       UUID/BIGINT REFERENCES contacts(id) ON DELETE SET NULL
deal_id          UUID/BIGINT REFERENCES deals(id) ON DELETE SET NULL
title            VARCHAR(255) NOT NULL
description      TEXT
start_time       TIMESTAMP NOT NULL
end_time         TIMESTAMP NOT NULL
type             ENUM('meeting', 'call', 'demo', 'follow_up', 'internal', 'personal') DEFAULT 'meeting'
location         VARCHAR(500)
meeting_link     VARCHAR(500)
status           ENUM('scheduled', 'confirmed', 'completed', 'cancelled', 'no_show') DEFAULT 'scheduled'
priority         ENUM('high', 'medium', 'low') DEFAULT 'medium'
created_at       TIMESTAMP NOT NULL
updated_at       TIMESTAMP NOT NULL

INDEXES:
  - user_id, start_time ASC
  - contact_id
  - deal_id
  - type, start_time
  - status, start_time

COMPUTED FIELDS (in queries):
  - contact_name (from contacts)
  - contact_company (from contacts)
  - attendees (from event_attendees)
  - preparation (from meeting_preparations)
  - outcome (from meeting_outcomes)
  - insights (from meeting_insights)
  - tags (from taggings)
```

#### `attendees`
```
id         UUID/BIGINT PRIMARY KEY
name       VARCHAR(255) NOT NULL
email      VARCHAR(255) NOT NULL
role       VARCHAR(100)
created_at TIMESTAMP NOT NULL

INDEXES:
  - email
```

#### `event_attendees` (join table)
```
id              UUID/BIGINT PRIMARY KEY
event_id        UUID/BIGINT NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE
attendee_id     UUID/BIGINT NOT NULL REFERENCES attendees(id) ON DELETE CASCADE
status          ENUM('accepted', 'declined', 'pending', 'tentative') DEFAULT 'pending'
created_at      TIMESTAMP NOT NULL
updated_at      TIMESTAMP NOT NULL

UNIQUE CONSTRAINT: (event_id, attendee_id)

INDEXES:
  - event_id
  - attendee_id
```

#### `meeting_preparations` (AI-generated meeting prep)
```
id                       UUID/BIGINT PRIMARY KEY
event_id                 UUID/BIGINT NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE
suggested_talking_points TEXT[] / JSON
recent_interactions      TEXT[] / JSON
deal_context             TEXT
competitor_intel         TEXT[] / JSON
personal_notes           TEXT[] / JSON
documents_to_share       TEXT[] / JSON
created_at               TIMESTAMP NOT NULL
updated_at               TIMESTAMP NOT NULL

INDEXES:
  - event_id (unique)
```

#### `meeting_outcomes`
```
id                  UUID/BIGINT PRIMARY KEY
event_id            UUID/BIGINT NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE
summary             TEXT NOT NULL
next_steps          TEXT[] / JSON
sentiment_score     INTEGER CHECK (sentiment_score >= -100 AND sentiment_score <= 100)
key_decisions       TEXT[] / JSON
follow_up_required  BOOLEAN DEFAULT false
follow_up_date      TIMESTAMP
meeting_rating      INTEGER CHECK (meeting_rating >= 1 AND meeting_rating <= 5)
created_at          TIMESTAMP NOT NULL
updated_at          TIMESTAMP NOT NULL

INDEXES:
  - event_id (unique)
  - follow_up_required
```

#### `meeting_insights`
```
id               UUID/BIGINT PRIMARY KEY
event_id         UUID/BIGINT NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE
insight_type     ENUM('opportunity', 'risk', 'preparation', 'follow_up') NOT NULL
title            VARCHAR(255) NOT NULL
description      TEXT NOT NULL
confidence       INTEGER CHECK (confidence >= 0 AND confidence <= 100)
actionable       BOOLEAN DEFAULT false
suggested_action TEXT
created_at       TIMESTAMP NOT NULL

INDEXES:
  - event_id, created_at DESC
  - insight_type
```

---

### 6. Cross-Entity Features

#### `tags`
```
id         UUID/BIGINT PRIMARY KEY
name       VARCHAR(100) UNIQUE NOT NULL
color      VARCHAR(7) (hex color code)
created_at TIMESTAMP NOT NULL

INDEXES:
  - name (unique)
```

#### `taggings` (polymorphic join table)
```
id             UUID/BIGINT PRIMARY KEY
tag_id         UUID/BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE
taggable_id    UUID/BIGINT NOT NULL
taggable_type  ENUM('contact', 'deal', 'conversation', 'calendar_event') NOT NULL
created_at     TIMESTAMP NOT NULL

UNIQUE CONSTRAINT: (tag_id, taggable_id, taggable_type)

INDEXES:
  - tag_id
  - taggable_id, taggable_type
```

#### `ai_insights` (generic AI insights for contacts)
```
id               UUID/BIGINT PRIMARY KEY
contact_id       UUID/BIGINT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE
insight_type     ENUM('opportunity', 'risk', 'suggestion', 'trend') NOT NULL
title            VARCHAR(255) NOT NULL
description      TEXT NOT NULL
confidence       INTEGER CHECK (confidence >= 0 AND confidence <= 100)
actionable       BOOLEAN DEFAULT false
suggested_action TEXT
created_at       TIMESTAMP NOT NULL
updated_at       TIMESTAMP NOT NULL

INDEXES:
  - contact_id, created_at DESC
  - insight_type
```

---

### 7. Notifications

#### `notifications`
```
id          UUID/BIGINT PRIMARY KEY
user_id     UUID/BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
type        ENUM('deal_update', 'message_received', 'meeting_reminder', 'ai_insight', 'task_due', 'at_risk_alert') NOT NULL
title       VARCHAR(255) NOT NULL
message     TEXT NOT NULL
priority    ENUM('high', 'medium', 'low') DEFAULT 'medium'
read        BOOLEAN DEFAULT false
action_url  VARCHAR(500)
metadata    JSON / JSONB (flexible data for notification context)
expires_at  TIMESTAMP
created_at  TIMESTAMP NOT NULL

INDEXES:
  - user_id, read, created_at DESC (composite for efficient queries)
  - expires_at
  - type
```

---

### 8. Dashboard & Analytics

#### `action_items` (dashboard smart actions)
```
id          UUID/BIGINT PRIMARY KEY
user_id     UUID/BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
icon        VARCHAR(50)
title       VARCHAR(255) NOT NULL
item_type   ENUM('suggestion', 'opportunity', 'warning') NOT NULL
dismissed   BOOLEAN DEFAULT false
created_at  TIMESTAMP NOT NULL
updated_at  TIMESTAMP NOT NULL

INDEXES:
  - user_id, dismissed, created_at DESC
  - item_type
```

---

## API Routes & Controllers

### Naming Convention for Controllers
- **Plural resource names**: `ContactsController`, `DealsController`
- **Actions as methods**: `index`, `show`, `create`, `update`, `delete`
- **Sub-resources as nested methods**: `add_activity`, `add_communication`

---

### 1. Authentication Routes

```
POST   /api/auth/login
  Controller: AuthController.login
  Body: { email, password }
  Response: { user, token, refresh_token }

POST   /api/auth/logout
  Controller: AuthController.logout
  Headers: Authorization: Bearer <token>
  Response: { success: true }

POST   /api/auth/refresh
  Controller: AuthController.refresh
  Body: { refresh_token }
  Response: { token, refresh_token }

GET    /api/auth/me
  Controller: AuthController.current_user
  Headers: Authorization: Bearer <token>
  Response: User
```

**Controller: `AuthController`**
- `login(params)` - Authenticate user, generate tokens
- `logout(user)` - Invalidate session
- `refresh(refresh_token)` - Generate new access token
- `current_user(token)` - Get current user from token

---

### 2. Dashboard Routes

```
GET    /api/dashboard/forecast
  Controller: DashboardController.forecast
  Response: { revenue, period, confidence, breakdown }

GET    /api/dashboard/action-items
  Controller: DashboardController.action_items
  Response: ActionItem[]

POST   /api/dashboard/action-items/:id/dismiss
  Controller: DashboardController.dismiss_action_item
  Response: { success: true }

GET    /api/dashboard/summary
  Controller: DashboardController.summary
  Response: { deals, contacts, stats }
```

**Controller: `DashboardController`**
- `forecast(user_id)` - Calculate revenue forecast
- `action_items(user_id)` - Get pending action items
- `dismiss_action_item(user_id, item_id)` - Dismiss action item
- `summary(user_id)` - Aggregate dashboard data

---

### 3. Contacts Routes

```
GET    /api/contacts
  Controller: ContactsController.index
  Query: { search?, filter?, sort?, page?, limit? }
  Response: { contacts: Contact[], total, page, limit }

GET    /api/contacts/:id
  Controller: ContactsController.show
  Response: Contact (with relations)

POST   /api/contacts
  Controller: ContactsController.create
  Body: Contact (without computed fields)
  Response: Contact

PUT    /api/contacts/:id
  Controller: ContactsController.update
  Body: Partial<Contact>
  Response: Contact

DELETE /api/contacts/:id
  Controller: ContactsController.delete
  Response: { success: true }

POST   /api/contacts/:id/communication
  Controller: ContactsController.add_communication
  Body: { type, occurred_at, subject?, summary }
  Response: CommunicationEvent

GET    /api/contacts/:id/ai-insights
  Controller: ContactsController.insights
  Response: AIInsight[]

GET    /api/contacts/stats
  Controller: ContactsController.stats
  Response: { total, high_value, at_risk, needs_follow_up }
```

**Controller: `ContactsController`**
- `index(user_id, params)` - List/search/filter contacts
- `show(user_id, contact_id)` - Get contact with all relations
- `create(user_id, params)` - Create new contact
- `update(user_id, contact_id, params)` - Update contact
- `delete(user_id, contact_id)` - Soft delete contact
- `add_communication(user_id, contact_id, params)` - Log communication event
- `insights(user_id, contact_id)` - Get AI insights for contact
- `stats(user_id)` - Get contacts statistics

---

### 4. Deals Routes

```
GET    /api/deals
  Controller: DealsController.index
  Query: { filter?, search?, page?, limit? }
  Response: { deals: Deal[], total, page, limit }

GET    /api/deals/:id
  Controller: DealsController.show
  Response: Deal (with activities, insights)

POST   /api/deals
  Controller: DealsController.create
  Body: Deal (without AI-computed fields)
  Response: Deal (with AI probability)

PUT    /api/deals/:id
  Controller: DealsController.update
  Body: Partial<Deal>
  Response: Deal (recalculated)

DELETE /api/deals/:id
  Controller: DealsController.delete
  Response: { success: true }

PATCH  /api/deals/:id/stage
  Controller: DealsController.update_stage
  Body: { stage }
  Response: Deal (with updated probability)

POST   /api/deals/:id/activities
  Controller: DealsController.add_activity
  Body: { type, occurred_at, description, outcome?, next_step? }
  Response: DealActivity

GET    /api/deals/forecast
  Controller: DealsController.forecast
  Response: { total_pipeline, weighted_forecast, deals_closing_this_month, monthly_forecast }

GET    /api/deals/stage-stats
  Controller: DealsController.stage_stats
  Response: StageStats[]
```

**Controller: `DealsController`**
- `index(user_id, params)` - List/filter deals
- `show(user_id, deal_id)` - Get deal with all relations
- `create(user_id, params)` - Create deal, calculate AI probability
- `update(user_id, deal_id, params)` - Update deal, recalculate AI fields
- `delete(user_id, deal_id)` - Soft delete deal
- `update_stage(user_id, deal_id, stage)` - Change stage, update probability
- `add_activity(user_id, deal_id, params)` - Add activity, trigger AI insights
- `forecast(user_id)` - Calculate pipeline forecast
- `stage_stats(user_id)` - Get statistics per stage

---

### 5. Messages/Conversations Routes

```
GET    /api/conversations
  Controller: ConversationsController.index
  Query: { filter?, search?, page?, limit? }
  Response: { conversations: Conversation[], total, page, limit }

GET    /api/conversations/:id
  Controller: ConversationsController.show
  Response: Conversation (with messages)

POST   /api/conversations/:id/messages
  Controller: ConversationsController.send_message
  Body: { content, type, subject? }
  Response: Message (with AI sentiment)

PATCH  /api/conversations/:id/priority
  Controller: ConversationsController.update_priority
  Body: { priority }
  Response: Conversation

PATCH  /api/conversations/:id/archive
  Controller: ConversationsController.archive
  Body: { archived }
  Response: Conversation

POST   /api/conversations/:id/tags
  Controller: ConversationsController.add_tag
  Body: { tag }
  Response: Conversation

GET    /api/messages/:id/ai-analysis
  Controller: MessagesController.analysis
  Response: MessageAnalysis

POST   /api/messages/smart-compose
  Controller: MessagesController.smart_compose
  Body: { conversation_id, draft_content? }
  Response: SmartCompose

GET    /api/messages/templates
  Controller: MessagesController.templates
  Query: { category? }
  Response: MessageTemplate[]

GET    /api/messages/stats
  Controller: ConversationsController.stats
  Response: { total, unread, high_priority, needs_follow_up, avg_response_time }

GET    /api/messages/sentiment-overview
  Controller: ConversationsController.sentiment_overview
  Response: { positive: %, neutral: %, negative: % }
```

**Controller: `ConversationsController`**
- `index(user_id, params)` - List/filter conversations
- `show(user_id, conversation_id)` - Get conversation with messages
- `send_message(user_id, conversation_id, params)` - Send message, analyze sentiment
- `update_priority(user_id, conversation_id, priority)` - Update priority
- `archive(user_id, conversation_id, archived)` - Archive/unarchive
- `add_tag(user_id, conversation_id, tag)` - Add tag to conversation
- `stats(user_id)` - Get messages statistics
- `sentiment_overview(user_id)` - Get sentiment distribution

**Controller: `MessagesController`**
- `analysis(user_id, message_id)` - Get detailed AI analysis
- `smart_compose(user_id, params)` - Generate smart compose suggestions
- `templates(user_id, category?)` - List message templates

---

### 6. Calendar Routes

```
GET    /api/calendar/events
  Controller: CalendarController.index
  Query: { start?, end?, filter?, page?, limit? }
  Response: { events: CalendarEvent[], total, page, limit }

GET    /api/calendar/events/:id
  Controller: CalendarController.show
  Response: CalendarEvent (with preparation, outcome, insights)

POST   /api/calendar/events
  Controller: CalendarController.create
  Body: CalendarEvent (without AI fields)
  Response: CalendarEvent (with AI preparation)

PUT    /api/calendar/events/:id
  Controller: CalendarController.update
  Body: Partial<CalendarEvent>
  Response: CalendarEvent (regenerate preparation if needed)

DELETE /api/calendar/events/:id
  Controller: CalendarController.delete
  Response: { success: true }

PATCH  /api/calendar/events/:id/status
  Controller: CalendarController.update_status
  Body: { status }
  Response: CalendarEvent

POST   /api/calendar/events/:id/outcome
  Controller: CalendarController.add_outcome
  Body: MeetingOutcome
  Response: CalendarEvent (auto-create follow-up if needed)

GET    /api/calendar/events/:id/preparation
  Controller: CalendarController.preparation
  Response: MeetingPreparation

POST   /api/calendar/smart-scheduling
  Controller: CalendarController.smart_schedule
  Body: { contact_id?, deal_id?, duration, preferred_times? }
  Response: SmartScheduling

GET    /api/calendar/stats
  Controller: CalendarController.stats
  Response: { total_this_week, meetings_this_week, high_priority_this_week, follow_ups_needed }
```

**Controller: `CalendarController`**
- `index(user_id, params)` - List/filter events
- `show(user_id, event_id)` - Get event with all relations
- `create(user_id, params)` - Create event, generate AI preparation
- `update(user_id, event_id, params)` - Update event
- `delete(user_id, event_id)` - Delete event
- `update_status(user_id, event_id, status)` - Update event status
- `add_outcome(user_id, event_id, outcome)` - Add meeting outcome, create follow-up
- `preparation(user_id, event_id)` - Get AI-generated meeting prep
- `smart_schedule(user_id, params)` - Suggest optimal meeting times
- `stats(user_id)` - Get calendar statistics

---

### 7. Notifications Routes

```
GET    /api/notifications
  Controller: NotificationsController.index
  Query: { read?, page?, limit? }
  Response: { notifications: Notification[], total, page, limit }

PATCH  /api/notifications/:id/read
  Controller: NotificationsController.mark_read
  Body: { read }
  Response: Notification

DELETE /api/notifications/:id
  Controller: NotificationsController.delete
  Response: { success: true }

GET    /api/notifications/unread-count
  Controller: NotificationsController.unread_count
  Response: { count }
```

**Controller: `NotificationsController`**
- `index(user_id, params)` - List notifications
- `mark_read(user_id, notification_id, read)` - Mark as read/unread
- `delete(user_id, notification_id)` - Delete notification
- `unread_count(user_id)` - Get unread count

---

### 8. Global Search Routes

```
GET    /api/search
  Controller: SearchController.search
  Query: { q, type? }
  Response: { contacts: [], deals: [], messages: [], events: [] }
```

**Controller: `SearchController`**
- `search(user_id, query, type?)` - Search across all entities

---

### 9. Tags Routes

```
GET    /api/tags
  Controller: TagsController.index
  Response: Tag[]

POST   /api/tags
  Controller: TagsController.create
  Body: { name, color? }
  Response: Tag

DELETE /api/tags/:id
  Controller: TagsController.delete
  Response: { success: true }
```

**Controller: `TagsController`**
- `index()` - List all tags
- `create(params)` - Create new tag
- `delete(tag_id)` - Delete tag (and all taggings)

---

## Data Integrity & Validation Rules

### Contacts
- `email` must be valid email format
- `health_score` must be 0-100
- `churn_risk` must be 0-100
- `phone` should follow international format (optional)

### Deals
- `value` must be >= 0
- `probability` must be 0-100
- `expected_close_date` should be >= created_at
- Cannot change stage to `closed_won` or `closed_lost` without closing date

### Messages
- `content` cannot be empty
- `sentiment` and `confidence` should be calculated by AI service
- `status` progression: sent → delivered → read → replied

### Calendar Events
- `end_time` must be > `start_time`
- Cannot have overlapping events (optional warning, not constraint)
- `meeting_rating` must be 1-5 if provided

### General Rules
- All foreign keys must reference existing records
- Soft deletes: set `deleted_at` instead of removing record
- Timestamps: always set `created_at` on insert, `updated_at` on update
- User isolation: all queries must filter by `user_id` for security

---

## Performance Optimization Strategies

### Database Indexes
All critical indexes are listed in each table schema above. Key strategies:
- Composite indexes for common query patterns (e.g., `user_id, created_at DESC`)
- Indexes on foreign keys for join performance
- Indexes on filter/sort fields (health_score, churn_risk, stage, etc.)
- Text search indexes on name/company fields

### Query Optimization
- Use pagination for all list endpoints (default: 25 items per page)
- Lazy load relations (don't fetch all relations by default)
- Use database-level aggregations for stats endpoints
- Implement query result caching for expensive computations

### Computed Fields Strategy
Fields like `total_deals_count`, `total_deals_value`, `unread_count` should be:
- Updated via triggers or background jobs
- Denormalized for read performance
- Recalculated on relevant entity changes

---

## API Response Formats

### Success Response
```json
{
  "data": { ... } or [ ... ],
  "meta": {
    "total": 100,
    "page": 1,
    "limit": 25
  }
}
```

### Error Response
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message",
    "details": {}
  }
}
```

### Common Error Codes
- `UNAUTHORIZED` - Invalid or missing token
- `FORBIDDEN` - User doesn't have access to resource
- `NOT_FOUND` - Resource not found
- `VALIDATION_ERROR` - Input validation failed
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `AI_SERVICE_ERROR` - AI service unavailable

---

## Next Steps (After Approval)

Once this generic plan is approved, the following will be created:

1. **Phoenix/Elixir-Specific Implementation Plan**
   - Ecto schemas and migrations
   - Phoenix contexts (Contacts, Deals, Messages, Calendar)
   - Phoenix controllers and views
   - Channel setup for real-time features
   - Guardian setup for JWT authentication

2. **AI Service Integration Plan**
   - AI service module architecture
   - External API integration (if using third-party)
   - Internal ML model integration (if self-hosted)
   - Background job setup for AI processing

3. **Testing Strategy**
   - Unit tests for business logic
   - Integration tests for API endpoints
   - Test data factories

4. **Deployment & Infrastructure**
   - Database setup (PostgreSQL)
   - Environment configuration
   - API documentation generation

---

## Summary

This plan provides a complete, framework-agnostic backend architecture for Flow CRM with:

- ✅ 20+ database tables with proper relations
- ✅ Comprehensive field definitions with types and constraints
- ✅ Clear naming conventions throughout
- ✅ RESTful API routes organized by domain
- ✅ Controller structure with clear responsibilities
- ✅ Data integrity rules and validation requirements
- ✅ Performance optimization strategies
- ✅ Scalable architecture ready for AI integration

The design supports all frontend features while maintaining clean separation of concerns and following industry best practices for CRM systems.
