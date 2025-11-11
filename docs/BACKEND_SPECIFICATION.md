# FLOW CRM - Backend API Specification

## Tech Stack (Framework Agnostic)
- RESTful API
- WebSocket/SSE for real-time updates
- AI/ML services integration
- Database with relational + time-series support

---

## Authentication

### Endpoints
```
POST   /api/auth/login
  Body: { email, password }
  Response: { user, token, refreshToken }

POST   /api/auth/logout
  Headers: Authorization: Bearer <token>
  Response: { success: true }

POST   /api/auth/refresh
  Body: { refreshToken }
  Response: { token, refreshToken }

GET    /api/auth/me
  Headers: Authorization: Bearer <token>
  Response: User
```

### User Model
```typescript
{
  id: string
  email: string
  name: string
  avatar?: string
  role: 'admin' | 'sales' | 'manager'
  preferences: {
    theme: 'light' | 'dark'
    notifications: boolean
    timezone: string
  }
  createdAt: Date
  lastLogin: Date
}
```

---

## Dashboard

### Endpoints
```
GET    /api/dashboard/forecast
  Response: {
    revenue: number
    period: string
    confidence: 'high' | 'medium' | 'low'
    breakdown: [{ source, amount, probability }]
  }

GET    /api/dashboard/action-items
  Response: ActionItem[]

POST   /api/dashboard/action-items/:id/dismiss
  Response: { success: true }

GET    /api/dashboard/summary
  Response: {
    deals: Deal[]
    contacts: Contact[]
    totalDealsValue: number
    atRiskContacts: number
    highProbabilityDeals: number
  }
```

### Models
```typescript
ActionItem {
  id, icon, title
  type: 'suggestion' | 'opportunity' | 'warning'
  timestamp: Date
  actions: [{ label, type: 'primary' | 'secondary' | 'dismiss' }]
}
```

---

## Contacts

### Endpoints
```
GET    /api/contacts
  Query: { search?, filter?: 'all' | 'high-value' | 'at-risk' | 'recent', sort? }
  Response: Contact[]

GET    /api/contacts/:id
  Response: Contact (full with history + insights)

POST   /api/contacts
  Body: Contact (without id, computed fields)
  Response: Contact

PUT    /api/contacts/:id
  Body: Partial<Contact>
  Response: Contact

DELETE /api/contacts/:id
  Response: { success: true }

POST   /api/contacts/:id/communication
  Body: { type: 'email' | 'call' | 'meeting' | 'note', date, subject?, summary }
  Response: CommunicationEvent (with AI sentiment + analysis)

GET    /api/contacts/:id/ai-insights
  Response: AIInsight[]

GET    /api/contacts/stats
  Response: { total, highValue, atRisk, needsFollowUp }
```

### Models
```typescript
Contact {
  id, name, email, phone, company, title, avatar?
  relationshipHealth: 'high' | 'medium' | 'low'
  healthScore: number // 0-100 (AI computed)
  lastContact: Date
  nextFollowUp?: Date
  sentiment: 'positive' | 'neutral' | 'negative'
  churnRisk: number // 0-100 (AI computed)
  totalDeals: number
  totalValue: number
  tags: string[]
  notes: string[]
  communicationHistory: CommunicationEvent[]
  aiInsights: AIInsight[]
}

CommunicationEvent {
  id, type: 'email' | 'call' | 'meeting' | 'note'
  date, subject?, summary
  sentiment: 'positive' | 'neutral' | 'negative'
  aiAnalysis?: string
}

AIInsight {
  id, type: 'opportunity' | 'risk' | 'suggestion' | 'trend'
  title, description
  confidence: number // 0-100
  actionable: boolean
  suggestedAction?: string
  date: Date
}
```

---

## Deals

### Endpoints
```
GET    /api/deals
  Query: { filter?: 'all' | 'hot' | 'at-risk' | 'closing-soon', search? }
  Response: Deal[]

GET    /api/deals/:id
  Response: Deal (full with activities + insights)

POST   /api/deals
  Body: Deal (without id, AI fields)
  Response: Deal (with AI probability)

PUT    /api/deals/:id
  Body: Partial<Deal>
  Response: Deal (recalculate AI fields)

DELETE /api/deals/:id
  Response: { success: true }

PATCH  /api/deals/:id/stage
  Body: { stage: DealStage }
  Response: Deal (with updated probability)

POST   /api/deals/:id/activities
  Body: { type, date, description, outcome?, nextStep? }
  Response: DealActivity (triggers AI insight generation)

GET    /api/deals/forecast
  Response: {
    totalPipeline: number
    weightedForecast: number
    dealsClosingThisMonth: number
    monthlyForecast: number
  }

GET    /api/deals/stage-stats
  Response: StageStats[]
```

### Models
```typescript
Deal {
  id, title, contactId, contactName, company, value
  stage: 'prospect' | 'qualified' | 'proposal' | 'negotiation' | 'closed-won' | 'closed-lost'
  probability: number // 0-100 (AI computed)
  confidence: 'high' | 'medium' | 'low' (AI computed)
  expectedCloseDate, createdDate, lastActivity
  description, tags
  activities: DealActivity[]
  aiInsights: DealInsight[]
  competitorMentioned?: string
  riskFactors: string[] (AI extracted)
  positiveSignals: string[] (AI extracted)
  priority: 'high' | 'medium' | 'low'
}

DealActivity {
  id, type: 'call' | 'email' | 'meeting' | 'proposal' | 'demo' | 'note'
  date, description, outcome?, nextStep?
}

DealInsight {
  id, type: 'opportunity' | 'risk' | 'suggestion' | 'competitor'
  title, description, impact: 'high' | 'medium' | 'low'
  actionable, suggestedAction?, confidence, date
}

StageStats {
  stage, count, totalValue, avgProbability, avgDaysInStage
}
```

### AI Logic Requirements
- **Probability Calculation**: Based on stage + positive signals - risk factors - competitor mention
- **Confidence Level**: Based on recent activity (past 7 days) + signal/risk ratio
- **Risk/Signal Extraction**: NLP on activities to detect risks and positive signals

---

## Messages

### Endpoints
```
GET    /api/conversations
  Query: { filter?: 'all' | 'unread' | 'high-priority' | 'follow-up', search? }
  Response: Conversation[]

GET    /api/conversations/:id
  Response: Conversation (with messages)

POST   /api/conversations/:id/messages
  Body: { content, type: 'email' | 'sms' | 'chat', subject? }
  Response: Message (with AI sentiment)

PATCH  /api/conversations/:id/priority
  Body: { priority: 'high' | 'medium' | 'low' }
  Response: Conversation

PATCH  /api/conversations/:id/archive
  Body: { archived: boolean }
  Response: Conversation

POST   /api/conversations/:id/tags
  Body: { tag: string }
  Response: Conversation

GET    /api/messages/:id/ai-analysis
  Response: MessageAnalysis (full AI breakdown)

POST   /api/messages/smart-compose
  Body: { conversationId, draftContent }
  Response: SmartCompose

GET    /api/messages/templates
  Query: { category? }
  Response: MessageTemplate[]

GET    /api/messages/stats
  Response: { total, unread, highPriority, needsFollowUp, averageResponseTime }

GET    /api/messages/sentiment-overview
  Response: { positive: %, neutral: %, negative: % }
```

### Models
```typescript
Conversation {
  id, contactId, contactName, contactCompany
  lastMessage: Date, unreadCount
  messages: Message[]
  overallSentiment: 'positive' | 'neutral' | 'negative' (AI computed)
  sentimentTrend: 'improving' | 'stable' | 'declining' (AI computed)
  aiSummary: string (AI generated)
  tags: string[], priority: 'high' | 'medium' | 'low'
  archived: boolean
}

Message {
  id, conversationId, senderId, senderName
  senderType: 'user' | 'contact'
  content, timestamp
  type: 'email' | 'sms' | 'chat'
  subject?, sentiment: 'positive' | 'neutral' | 'negative'
  confidence: number // 0-100
  aiAnalysis?: MessageAnalysis
  attachments?: Attachment[]
  status: 'sent' | 'delivered' | 'read' | 'replied'
}

MessageAnalysis {
  keyTopics: string[]
  emotionalTone: string
  urgencyLevel: 'high' | 'medium' | 'low'
  businessIntent: 'inquiry' | 'complaint' | 'support' | 'purchase' | 'follow-up'
  suggestedResponse: string
  responseTime: string
  actionItems: string[]
}

SmartCompose {
  suggestions: string[]
  toneAdjustments: {
    current: 'formal' | 'casual' | 'friendly' | 'urgent'
    alternatives: [{ tone, preview }]
  }
  templateSuggestions: MessageTemplate[]
}

MessageTemplate {
  id, name, category: 'follow-up' | 'meeting' | 'proposal' | 'support' | 'introduction'
  content, variables: string[]
}

Attachment {
  id, name, type, size, url
}
```

### AI Logic Requirements
- **Sentiment Analysis**: Per message + overall conversation trend
- **Intent Classification**: Business intent from message content
- **Smart Compose**: Context-aware suggestions + tone adjustments
- **Urgency Detection**: Based on keywords and sender patterns

---

## Calendar

### Endpoints
```
GET    /api/calendar/events
  Query: { start?: Date, end?: Date, filter?: 'all' | 'meetings' | 'high-priority' | 'this-week' | 'follow-ups' }
  Response: CalendarEvent[]

GET    /api/calendar/events/:id
  Response: CalendarEvent (full with preparation + insights)

POST   /api/calendar/events
  Body: CalendarEvent (without id, AI fields)
  Response: CalendarEvent (with AI preparation + insights)

PUT    /api/calendar/events/:id
  Body: Partial<CalendarEvent>
  Response: CalendarEvent (regenerate preparation if contact/deal changed)

DELETE /api/calendar/events/:id
  Response: { success: true }

PATCH  /api/calendar/events/:id/status
  Body: { status: 'scheduled' | 'confirmed' | 'completed' | 'cancelled' | 'no-show' }
  Response: CalendarEvent

POST   /api/calendar/events/:id/outcome
  Body: MeetingOutcome
  Response: CalendarEvent (auto-creates follow-up event if needed)

GET    /api/calendar/events/:id/preparation
  Response: MeetingPreparation (AI generated)

POST   /api/calendar/smart-scheduling
  Body: { contactId?, dealId?, duration, preferredTimes? }
  Response: SmartScheduling

GET    /api/calendar/stats
  Response: { totalThisWeek, meetingsThisWeek, highPriorityThisWeek, followUpsNeeded }
```

### Models
```typescript
CalendarEvent {
  id, title, description?
  startTime, endTime
  type: 'meeting' | 'call' | 'demo' | 'follow-up' | 'internal' | 'personal'
  contactId?, contactName?, contactCompany?, dealId?
  location?, meetingLink?
  attendees: Attendee[]
  status: 'scheduled' | 'confirmed' | 'completed' | 'cancelled' | 'no-show'
  aiInsights: MeetingInsight[] (AI generated)
  preparation: MeetingPreparation (AI generated)
  outcome?: MeetingOutcome
  priority: 'high' | 'medium' | 'low'
  tags: string[]
}

Attendee {
  id, name, email, role
  status: 'accepted' | 'declined' | 'pending' | 'tentative'
}

MeetingInsight {
  id, type: 'opportunity' | 'risk' | 'preparation' | 'follow-up'
  title, description, confidence
  actionable, suggestedAction?
}

MeetingPreparation {
  suggestedTalkingPoints: string[] (AI generated based on type + contact + deal)
  recentInteractions: string[] (pulled from communication history)
  dealContext?: string
  competitorIntel?: string[]
  personalNotes: string[]
  documentsToShare: string[]
}

MeetingOutcome {
  summary, nextSteps: string[]
  sentimentScore: number // -100 to 100
  keyDecisions: string[]
  followUpRequired: boolean
  followUpDate?: Date
  meetingRating: 1 | 2 | 3 | 4 | 5
}

SmartScheduling {
  suggestedTimes: ScheduleSuggestion[]
  conflictWarnings: ConflictWarning[]
  travelTimeEstimate?: number
  preparationTimeNeeded: number
}

ScheduleSuggestion {
  startTime, endTime, reason, confidence
}

ConflictWarning {
  type: 'double-booking' | 'travel-time' | 'preparation' | 'back-to-back'
  message, severity: 'high' | 'medium' | 'low'
}
```

### AI Logic Requirements
- **Meeting Preparation**: Generate talking points based on event type (demo/follow-up/meeting)
- **Context Gathering**: Pull recent interactions from contact communication history
- **Deal Context**: Link to active deals and surface relevant info
- **Smart Scheduling**: Analyze calendar patterns, suggest optimal times, detect conflicts

---

## Notifications

### Endpoints
```
GET    /api/notifications
  Query: { read?: boolean, limit?, offset? }
  Response: Notification[]

PATCH  /api/notifications/:id/read
  Body: { read: boolean }
  Response: Notification

DELETE /api/notifications/:id
  Response: { success: true }

GET    /api/notifications/unread-count
  Response: { count: number }
```

### Models
```typescript
Notification {
  id, userId
  type: 'deal_update' | 'message_received' | 'meeting_reminder' | 'ai_insight' | 'task_due' | 'at_risk_alert'
  title, message, priority: 'high' | 'medium' | 'low'
  read: boolean
  actionUrl?: string
  metadata?: Record<string, any>
  createdAt, expiresAt?: Date
}
```

### Real-time Channel (WebSocket/SSE)
```
Channel: user:{userId}:notifications

Events:
  - notification:new { notification }
  - notification:read { id }
  - notification:deleted { id }
```

---

## Real-time Updates

### Channels (WebSocket/Phoenix Channels)

```
Channel: user:{userId}:deals
Events:
  - deal:created { deal }
  - deal:updated { id, changes }
  - deal:stage_changed { id, oldStage, newStage, probability }
  - deal:activity_added { dealId, activity }

Channel: user:{userId}:messages
Events:
  - message:received { conversationId, message }
  - conversation:updated { id, changes }
  - conversation:unread_count { conversationId, count }

Channel: user:{userId}:calendar
Events:
  - event:created { event }
  - event:updated { id, changes }
  - event:reminder { id, minutesUntil }

Channel: user:{userId}:contacts
Events:
  - contact:updated { id, changes }
  - contact:health_changed { id, oldScore, newScore }
```

---

## AI Services (Internal/External)

### Required AI Capabilities

#### 1. Sentiment Analysis
```
POST /ai/sentiment
  Body: { text, context? }
  Response: { sentiment: 'positive' | 'neutral' | 'negative', confidence: 0-100, emotionalTone }
```

#### 2. Probability Calculation (Deals)
```
POST /ai/deal-probability
  Body: { stage, activities, riskFactors, positiveSignals, competitorMentioned }
  Response: { probability: 0-100, confidence: 'high' | 'medium' | 'low', reasoning }
```

#### 3. Risk Assessment (Contacts)
```
POST /ai/churn-risk
  Body: { contactId, communicationHistory, dealHistory, engagementMetrics }
  Response: { churnRisk: 0-100, riskFactors: string[], recommendations }
```

#### 4. Message Analysis
```
POST /ai/message-analysis
  Body: { content, conversationHistory? }
  Response: MessageAnalysis
```

#### 5. Smart Compose
```
POST /ai/smart-compose
  Body: { conversationContext, draftContent?, tone? }
  Response: SmartCompose
```

#### 6. Meeting Preparation
```
POST /ai/meeting-preparation
  Body: { eventType, contactId?, dealId?, communicationHistory? }
  Response: MeetingPreparation
```

#### 7. Natural Language Query (Global Search)
```
POST /ai/query
  Body: { query: "show me deals about to close" }
  Response: { intent, filters, entities, suggestedRoute }
```

#### 8. Insight Generation
```
POST /ai/generate-insights
  Body: { entityType: 'contact' | 'deal', entityId, context }
  Response: AIInsight[]
```

---

## Search

### Global Search Endpoint
```
GET    /api/search
  Query: { q, type?: 'all' | 'contacts' | 'deals' | 'messages' | 'events' }
  Response: {
    contacts: Contact[]
    deals: Deal[]
    messages: Message[]
    events: CalendarEvent[]
  }
```

---

## Database Indexes (Recommended)

```
contacts:
  - healthScore (desc)
  - churnRisk (desc)
  - lastContact (desc)
  - company, name (text search)

deals:
  - stage, probability (compound)
  - expectedCloseDate (asc)
  - value (desc)
  - lastActivity (desc)

messages:
  - conversationId, timestamp (compound)
  - sentiment, timestamp (compound)

calendar_events:
  - userId, startTime (compound)
  - type, startTime (compound)
  - status, startTime (compound)

notifications:
  - userId, read, createdAt (compound)
```

---

## Background Jobs/Workers

1. **AI Insight Generation**: Periodic (hourly) - generate new insights for contacts/deals
2. **Health Score Calculation**: Daily - recalculate contact health scores
3. **Churn Risk Update**: Daily - update churn risk for all contacts
4. **Deal Probability Update**: On activity change - recalculate probabilities
5. **Notification Cleanup**: Daily - delete expired notifications
6. **Meeting Reminders**: Continuous - send reminders 1 day, 1 hour, 15 min before
7. **Sentiment Trend Analysis**: Daily - analyze conversation sentiment trends

---

## Rate Limiting

```
Authentication: 5 req/min
AI Services: 20 req/min per user
Standard API: 100 req/min per user
WebSocket: 1000 messages/min per connection
```

---

## Error Responses

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message",
    "details": {}
  }
}
```

Common codes: `UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION_ERROR`, `RATE_LIMIT_EXCEEDED`, `AI_SERVICE_ERROR`
