# WebSocket Connections Documentation

This document describes all WebSocket connections used in the Flow CRM frontend application, including connection details, event types, and expected message formats.

## Overview

The application uses a single WebSocket connection instance (`wsClient`) that is shared across all stores. The connection is managed centrally and provides real-time updates for deals, contacts, and notifications.

## Connection Details

### Connection URL
- **Environment Variable**: `VITE_WS_URL`
- **Default**: `ws://localhost:4545`
- **Production**: Configure via `VITE_WS_URL` (e.g., `wss://api.flow-crm.com`)

### Authentication
The WebSocket connection is authenticated using a JWT token passed as a query parameter:
```
ws://{host}?token={jwt_token}
```

### Connection Lifecycle
1. **Connection**: Established automatically after successful login or when fetching current user (if already authenticated)
2. **Reconnection**: Automatic reconnection with exponential backoff (max 5 attempts)
   - Initial delay: 1000ms
   - Backoff formula: `delay * 2^(attempt - 1)`
3. **Disconnection**: Triggered on user logout

## Message Format

All WebSocket messages follow a consistent JSON structure:

```typescript
{
  event: string,  // Event name (e.g., "deal:created")
  data: any       // Event-specific payload
}
```

### Sending Messages
To send a message to the server:
```typescript
wsClient.send(event: string, data: any)
```

The client will automatically format it as: `{ event, data }`

## WebSocket Events

### Deal Events

#### `deal:created`
**Description**: Triggered when a new deal is created.

**Expected Payload**:
```typescript
{
  id: string
  title: string
  contactId: string
  contactName: string
  company: string
  value: number
  stage: DealStage
  probability: number  // 0-100
  confidence: 'high' | 'medium' | 'low'
  expectedCloseDate: Date
  createdDate: Date
  lastActivity: Date
  description: string
  tags: string[]
  activities: DealActivity[]
  aiInsights: DealInsight[]
  competitorMentioned?: string
  riskFactors: string[]
  positiveSignals: string[]
  priority: 'high' | 'medium' | 'low'
}
```

**Handler Location**: `DealsStore.setupWebSocket()`

**Action**: Adds the new deal to the beginning of the deals array.

---

#### `deal:updated`
**Description**: Triggered when a deal is updated.

**Expected Payload**:
```typescript
{
  id: string
  changes: Partial<Deal>  // Partial deal object with updated fields
}
```

**Handler Location**: `DealsStore.setupWebSocket()`

**Action**: Updates the deal in the deals array and selectedDeal (if applicable).

---

#### `deal:stage_changed`
**Description**: Triggered when a deal moves to a different stage.

**Expected Payload**:
```typescript
{
  id: string
  stage: DealStage  // 'prospect' | 'qualified' | 'proposal' | 'negotiation' | 'closed-won' | 'closed-lost'
  probability: number  // Updated probability (0-100)
}
```

**Handler Location**: `DealsStore.setupWebSocket()`

**Action**: Updates the deal's stage and probability in the deals array.

---

#### `deal:activity_added`
**Description**: Triggered when a new activity is added to a deal.

**Expected Payload**:
```typescript
{
  dealId: string
  activity: {
    id: string
    type: 'call' | 'email' | 'meeting' | 'proposal' | 'demo' | 'note'
    date: Date
    description: string
    outcome?: string
    nextStep?: string
  }
}
```

**Handler Location**: `DealsStore.setupWebSocket()`

**Action**: Adds the activity to the deal's activities array and updates lastActivity timestamp.

---

### Contact Events

#### `contact:updated`
**Description**: Triggered when a contact is updated.

**Expected Payload**:
```typescript
{
  id: string
  changes: Partial<Contact>  // Partial contact object with updated fields
}
```

**Handler Location**: `ContactsStore.setupWebSocket()`

**Action**: Updates the contact in the contacts array and selectedContact (if applicable).

---

#### `contact:health_changed`
**Description**: Triggered when a contact's health score changes.

**Expected Payload**:
```typescript
{
  id: string
  oldScore: number  // Previous health score (0-100)
  newScore: number  // New health score (0-100)
}
```

**Handler Location**: `ContactsStore.setupWebSocket()`

**Action**: Updates the contact's healthScore and relationshipHealth:
- `newScore > 70`: 'high'
- `newScore > 40`: 'medium'
- Otherwise: 'low'

---

### Notification Events

#### `notification:new`
**Description**: Triggered when a new notification is received.

**Expected Payload**:
```typescript
{
  // Notification object structure (currently logged only)
  // Expected to be expanded in the future
}
```

**Handler Location**: `RootStore.setupWebSocketHandlers()`

**Action**: Currently logs the notification. Can be extended to display notifications in the UI.

---

## Implementation Details

### WebSocket Client Class

The `WebSocketClient` class (`src/api/websocket.ts`) provides:

- **Event-based messaging**: Register handlers with `on(event, handler)` and remove with `off(event, handler)`
- **Automatic reconnection**: Exponential backoff with configurable max attempts
- **Connection state management**: Prevents duplicate connections
- **Error handling**: Logs errors and handles connection failures gracefully

### Store Integration

Stores register their WebSocket handlers in their constructors:

- **DealsStore**: Registers deal-related event handlers
- **ContactsStore**: Registers contact-related event handlers
- **RootStore**: Registers global notification handlers

All handlers use MobX's `runInAction()` to ensure state updates are properly tracked.

### Connection Management

The WebSocket connection is managed by `UserStore`:

- **Connect**: Called after successful login (`UserStore.login()`) or when fetching current user (`UserStore.fetchCurrentUser()`)
- **Disconnect**: Called during logout (`UserStore.logout()`)

## Usage Example

```typescript
import { wsClient } from '../api/websocket'

// Register an event handler
wsClient.on('deal:created', (deal) => {
  console.log('New deal created:', deal)
  // Update your store state here
})

// Send a message to the server
wsClient.send('deal:subscribe', { dealId: '123' })

// Remove an event handler
const handler = (data) => console.log(data)
wsClient.on('deal:updated', handler)
wsClient.off('deal:updated', handler)
```

## Backend Requirements

The backend WebSocket server should:

1. Accept connections with token authentication via query parameter
2. Validate the JWT token before establishing the connection
3. Send messages in the format: `{ event: string, data: any }`
4. Handle client disconnections gracefully
5. Support all event types listed above

## Future Enhancements

Potential improvements:

- Add message acknowledgment/confirmation system
- Implement heartbeat/ping-pong for connection health monitoring
- Add support for subscribing/unsubscribing to specific channels
- Implement message queuing for offline scenarios
- Add WebSocket connection status indicator in UI
- Expand notification event handling with UI integration

