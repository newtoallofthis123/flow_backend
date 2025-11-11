# FLOW CRM - Frontend Architecture & Implementation

**Date:** November 11, 2025

---

## Tech Stack

### Core
- **React** 19.1.1 - UI library
- **TypeScript** 5.7.3 - Type safety
- **Vite** 7.1.7 - Build tool & dev server

### State Management
- **MobX** 6.15.0 - Observable state management
- **mobx-react-lite** 4.1.0 - React bindings

### Routing
- **React Router DOM** 7.9.3 - Client-side routing

### Styling
- **Tailwind CSS** 4.1.13 - Utility-first CSS
- **Custom CSS variables** - Theme system (light/dark)

### Icons
- **Lucide React** 0.544.0 - Icon library

---

## Project Structure

```
/src
  /components
    /dashboard          # Dashboard-specific components
      - AIForecastCard.tsx
      - SmartActionFeed.tsx
    /layout             # App shell components
      - Sidebar.tsx
      - Header.tsx
      - MainLayout.tsx
      - AICopilot.tsx
    /ui                 # Reusable UI primitives
      - SearchBar.tsx
      - AIInsight.tsx
      - HealthScore.tsx
      - SentimentIndicator.tsx
      - ProbabilityBadge.tsx
      - ThemeToggle.tsx
  /pages                # Route-level pages
    - Dashboard.tsx
    - Contacts.tsx
    - Deals.tsx
    - Messages.tsx
    - Calendar.tsx
  /stores               # MobX state stores
    - RootStore.ts
    - ContactsStore.ts
    - DealsStore.ts
    - MessagesStore.ts
    - CalendarStore.ts
    - DashboardStore.ts
    - ThemeStore.ts
    - UserStore.ts
  /lib                  # Utilities
    - utils.ts
  - App.tsx             # Root component
  - index.css           # Global styles + Tailwind
  - main.tsx            # Entry point
```

---

## State Management Architecture

### MobX Pattern

**RootStore** - Single source of truth
```typescript
export class RootStore {
  userStore: UserStore
  dashboardStore: DashboardStore
  contactsStore: ContactsStore
  dealsStore: DealsStore
  messagesStore: MessagesStore
  calendarStore: CalendarStore
  themeStore: ThemeStore

  constructor() {
    this.userStore = new UserStore(this)
    this.dashboardStore = new DashboardStore(this)
    // ... initialize all stores
  }
}
```

**React Context Provider**
```typescript
// main.tsx
const rootStore = new RootStore()

<RootStoreContext.Provider value={rootStore}>
  <App />
</RootStoreContext.Provider>
```

**Store Access in Components**
```typescript
const { contactsStore } = useRootStore()
const { filteredContacts, searchQuery } = contactsStore
```

### Store Pattern

Each store follows consistent structure:

1. **Observable State** - Data fields
2. **Computed Values** - Derived state with `get`
3. **Actions** - State mutations
4. **Private Methods** - Internal logic
5. **Constructor** - `makeAutoObservable()` + data loading

Example:
```typescript
export class ContactsStore {
  // Observable state
  contacts: Contact[] = []
  selectedContact: Contact | null = null
  searchQuery = ''
  filterBy: 'all' | 'high-value' | 'at-risk' | 'recent' = 'all'
  isLoading = false

  constructor() {
    makeAutoObservable(this) // Makes all fields observable
    this.loadMockData()
  }

  // Computed values
  get filteredContacts() {
    let filtered = this.contacts
    if (this.searchQuery) {
      filtered = filtered.filter(/* ... */)
    }
    // Apply filters
    return filtered.sort((a, b) => b.healthScore - a.healthScore)
  }

  get contactStats() {
    return {
      total: this.contacts.length,
      highValue: this.contacts.filter(c => c.totalValue > 50000).length,
      // ... more stats
    }
  }

  // Actions
  setSearchQuery = (query: string) => {
    this.searchQuery = query
  }

  selectContact = (contact: Contact) => {
    this.selectedContact = contact
  }

  // Private methods
  private loadMockData = () => {
    this.contacts = [/* mock data */]
  }
}
```

### Key MobX Benefits

- **Automatic reactivity**: Components re-render when observed data changes
- **Computed values**: Memoized derived state
- **No boilerplate**: No reducers, actions creators, or selectors
- **TypeScript-friendly**: Classes provide excellent type inference

---

## Routing Architecture

### Route Structure
```typescript
// App.tsx
const router = createBrowserRouter([
  {
    path: '/',
    element: <MainLayout />,
    children: [
      { path: '/', element: <Navigate to="/dashboard" /> },
      { path: '/dashboard', element: <Dashboard /> },
      { path: '/contacts', element: <Contacts /> },
      { path: '/contacts/:id', element: <Contacts /> }, // Detail view
      { path: '/deals', element: <Deals /> },
      { path: '/deals/:id', element: <Deals /> },
      { path: '/messages', element: <Messages /> },
      { path: '/messages/:id', element: <Messages /> },
      { path: '/calendar', element: <Calendar /> },
      { path: '/calendar/:id', element: <Calendar /> },
    ],
  },
])
```

### Layout Pattern

**MainLayout** wraps all pages with:
- Sidebar (left)
- Header (top)
- Main content area (center)
- AI Copilot (right)

```typescript
export default function MainLayout() {
  return (
    <div className="flex h-screen bg-background">
      <Sidebar />
      <div className="flex-1 flex flex-col">
        <Header />
        <main className="flex-1 overflow-auto">
          <Outlet /> {/* Nested routes render here */}
        </main>
      </div>
      <AICopilot />
    </div>
  )
}
```

### Master-Detail Pattern

Pages like Contacts, Deals, Messages use split-pane layout:
- **Left pane**: List view (cards/kanban)
- **Right pane**: Detail view (selected item)

URL pattern: `/contacts/:id` shows detail sidebar for contact ID

Implementation:
```typescript
const { id } = useParams()
const { contactsStore } = useRootStore()

useEffect(() => {
  if (id) {
    const contact = contactsStore.contacts.find(c => c.id === id)
    if (contact) contactsStore.selectContact(contact)
  }
}, [id])
```

---

## Component Architecture

### Component Categories

#### 1. Layout Components (`/components/layout`)
- **Sidebar**: Navigation, branding, route links
- **Header**: Global search, notifications, user menu, theme toggle
- **MainLayout**: Shell structure
- **AICopilot**: Right sidebar with AI insights

#### 2. Page Components (`/pages`)
- Top-level route components
- Compose UI from smaller components
- Connect to stores via `useRootStore()`
- Handle routing logic

#### 3. Feature Components (`/components/dashboard`)
- Domain-specific UI (e.g., AIForecastCard)
- Connected to stores
- Encapsulate feature logic

#### 4. UI Primitives (`/components/ui`)
- Reusable, generic components
- Accept props, no store dependencies
- Examples: SearchBar, HealthScore, SentimentIndicator

### Component Patterns

#### Observer Pattern
```typescript
import { observer } from 'mobx-react-lite'

const ContactList = observer(() => {
  const { contactsStore } = useRootStore()

  // Component re-renders when contactsStore.filteredContacts changes
  return contactsStore.filteredContacts.map(contact => (
    <ContactCard key={contact.id} contact={contact} />
  ))
})
```

#### Composition Pattern
```typescript
// Pages compose smaller components
<div className="flex">
  <div className="w-1/3">
    <SearchBar />
    <FilterTabs />
    <ContactList />
  </div>
  <div className="w-2/3">
    <ContactDetail />
  </div>
</div>
```

#### Prop Drilling Avoidance
- Use MobX stores via context instead of prop drilling
- Pass only data, not callbacks when possible
- Actions called directly on stores

---

## Data Flow

### 1. User Interaction
```
User clicks → Component calls store action → Store mutates state
```

Example:
```typescript
<button onClick={() => contactsStore.setFilter('at-risk')}>
  At Risk
</button>
```

### 2. State Updates
```
Store state changes → MobX tracks observers → Components re-render
```

### 3. Computed Values
```
Observable changes → Computed re-evaluates → Components see new value
```

Example:
```typescript
// In store
get filteredContacts() {
  // Automatically recomputes when contacts or searchQuery changes
  return this.contacts.filter(c =>
    c.name.includes(this.searchQuery)
  )
}

// In component
{contactsStore.filteredContacts.map(contact => ...)}
```

### 4. Side Effects (Future - API Integration)
```
Action called → API request → Response → Update store state
```

Example (future implementation):
```typescript
fetchContacts = async () => {
  this.isLoading = true
  try {
    const response = await fetch('/api/contacts')
    const data = await response.json()
    this.contacts = data
  } catch (error) {
    console.error(error)
  } finally {
    this.isLoading = false
  }
}
```

---

## Styling Architecture

### Tailwind Configuration

**Theme System**: Custom CSS variables for light/dark mode
```css
/* index.css */
:root {
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  --primary: 222.2 47.4% 11.2%;
  /* ... more variables */
}

.dark {
  --background: 222.2 84% 4.9%;
  --foreground: 210 40% 98%;
  --primary: 210 40% 98%;
  /* ... dark theme overrides */
}
```

**Tailwind Classes Reference CSS Variables**
```js
// tailwind.config.js
theme: {
  extend: {
    colors: {
      background: 'hsl(var(--background))',
      foreground: 'hsl(var(--foreground))',
      primary: 'hsl(var(--primary))',
      // ...
    }
  }
}
```

### Theme Toggle Implementation

```typescript
// ThemeStore.ts
export class ThemeStore {
  theme: 'light' | 'dark' = 'light'

  constructor() {
    makeAutoObservable(this)
    this.loadTheme()
  }

  toggleTheme = () => {
    this.theme = this.theme === 'light' ? 'dark' : 'light'
    this.applyTheme()
    localStorage.setItem('theme', this.theme)
  }

  private applyTheme = () => {
    if (this.theme === 'dark') {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }
}
```

### Styling Patterns

**Consistent Color Semantics**:
- `bg-background` - Page background
- `bg-card` - Card/panel background
- `bg-accent` - Hover states
- `text-foreground` - Primary text
- `text-muted-foreground` - Secondary text
- `border-border` - Borders

**Component Styling Example**:
```typescript
<div className="bg-card border border-border rounded-lg p-4 hover:bg-accent transition-colors">
  <h3 className="text-foreground font-semibold">Title</h3>
  <p className="text-muted-foreground text-sm">Description</p>
</div>
```

**Vercel-Inspired Design**:
- Matte black dark theme
- Clean, minimal light theme
- Subtle borders and shadows
- Smooth transitions

---

## UI Component Library

### SearchBar
- AI-powered search input
- Filter dropdown
- Count badges
- Props: `value`, `onChange`, `filters`, `onFilterChange`

### HealthScore
- Visual health indicator (0-100)
- Variants: `circular`, `bar`, `minimal`
- Color-coded: green (>70), yellow (40-70), red (<40)
- Optional trend indicator

### SentimentIndicator
- Shows sentiment: positive/neutral/negative
- Confidence percentage
- Color-coded icons
- Variants: `default`, `compact`, `detailed`

### ProbabilityBadge
- Deal probability display
- Confidence level (high/medium/low)
- Brain icon indicator
- Color: blue (high), yellow (medium), gray (low)

### AIInsight
- Displays AI-generated insights
- Types: opportunity, risk, suggestion, trend
- Confidence score
- Actionable suggestions
- Variants: `card`, `inline`, `toast`

---

## Data Models

### Type Definitions

All models defined in stores as TypeScript interfaces:

```typescript
// ContactsStore.ts
export interface Contact {
  id: string
  name: string
  email: string
  phone: string
  company: string
  title: string
  avatar?: string
  relationshipHealth: 'high' | 'medium' | 'low'
  healthScore: number
  lastContact: Date
  nextFollowUp?: Date
  sentiment: 'positive' | 'neutral' | 'negative'
  churnRisk: number
  totalDeals: number
  totalValue: number
  tags: string[]
  notes: string[]
  communicationHistory: CommunicationEvent[]
  aiInsights: AIInsight[]
}
```

### Mock Data Strategy

All data currently hardcoded in store constructors:

```typescript
private loadMockData = () => {
  this.contacts = [
    {
      id: '1',
      name: 'Sarah Williams',
      email: 'sarah.williams@techcorp.com',
      // ... full contact object
    },
    // ... more contacts
  ]
}
```

**Benefits**:
- Rapid prototyping
- No backend dependency
- Full UI development
- Easy to replace with API calls

**Future Migration**:
```typescript
// Replace loadMockData with:
async fetchContacts() {
  this.isLoading = true
  const response = await fetch('/api/contacts')
  this.contacts = await response.json()
  this.isLoading = false
}
```

---

## Key Features Implementation

### 1. Search & Filtering

**Pattern**: Store manages search/filter state, computed values apply logic

```typescript
// Store
searchQuery = ''
filterBy: 'all' | 'high-value' | 'at-risk' | 'recent' = 'all'

get filteredContacts() {
  let filtered = this.contacts

  if (this.searchQuery) {
    filtered = filtered.filter(c =>
      c.name.includes(this.searchQuery) ||
      c.company.includes(this.searchQuery)
    )
  }

  switch (this.filterBy) {
    case 'high-value':
      return filtered.filter(c => c.totalValue > 50000)
    case 'at-risk':
      return filtered.filter(c => c.churnRisk > 60)
    // ...
  }

  return filtered
}
```

### 2. AI Insights

**Pattern**: Each entity (contact, deal, message) has `aiInsights` array

```typescript
interface AIInsight {
  id: string
  type: 'opportunity' | 'risk' | 'suggestion' | 'trend'
  title: string
  description: string
  confidence: number
  actionable: boolean
  suggestedAction?: string
  date: Date
}
```

Displayed in sidebars using `AIInsight` component.

### 3. Sentiment Analysis

**Pattern**: Calculated per message, aggregated per conversation

```typescript
// Message-level
message.sentiment // 'positive' | 'neutral' | 'negative'
message.confidence // 0-100

// Conversation-level
conversation.overallSentiment // Aggregate
conversation.sentimentTrend // 'improving' | 'stable' | 'declining'
```

### 4. Probability Calculation (Deals)

**Pattern**: AI-computed field, updated on activity changes

```typescript
deal.probability // 0-100 (AI calculated)
deal.confidence // 'high' | 'medium' | 'low'
deal.riskFactors // ['Budget constraints', ...]
deal.positiveSignals // ['Budget confirmed', ...]
```

Algorithm (in store):
```typescript
calculateProbabilityForStage(stage, deal) {
  let base = stageBaseProbability[stage]

  if (deal.positiveSignals.length > deal.riskFactors.length) {
    base += 10
  } else if (deal.riskFactors.length > deal.positiveSignals.length) {
    base -= 15
  }

  if (deal.competitorMentioned) base -= 10

  return clamp(base, 0, 100)
}
```

### 5. Meeting Preparation

**Pattern**: AI-generated context per calendar event

```typescript
event.preparation = {
  suggestedTalkingPoints: string[] // Based on event type
  recentInteractions: string[] // From contact history
  dealContext?: string // Linked deal info
  competitorIntel?: string[] // Competitor mentions
  documentsToShare: string[]
}
```

Generated based on:
- Event type (demo → product overview, follow-up → recap)
- Contact communication history
- Linked deal data

### 6. Smart Compose (Messages)

**Pattern**: Context-aware suggestions

```typescript
smartCompose = {
  suggestions: string[] // Quick actions
  toneAdjustments: {
    current: 'friendly',
    alternatives: [
      { tone: 'formal', preview: '...' },
      { tone: 'casual', preview: '...' }
    ]
  }
  templateSuggestions: MessageTemplate[]
}
```

---

## Performance Considerations

### Current Optimizations

1. **MobX Reactivity**: Only re-render components observing changed data
2. **Computed Values**: Memoized, only recalculate when dependencies change
3. **Lazy Loading**: Detail views only load when selected

### Future Optimizations

1. **Virtual Scrolling**: For long lists (contacts, messages)
2. **Pagination**: API-level pagination for large datasets
3. **Debounced Search**: Delay search execution while typing
4. **Code Splitting**: Route-based code splitting with React.lazy()

```typescript
// Future implementation
const Contacts = lazy(() => import('./pages/Contacts'))
const Deals = lazy(() => import('./pages/Deals'))

<Suspense fallback={<LoadingSpinner />}>
  <Routes>
    <Route path="/contacts" element={<Contacts />} />
    <Route path="/deals" element={<Deals />} />
  </Routes>
</Suspense>
```

---

## Testing Strategy (Future)

### Unit Tests
- Store logic (actions, computed values)
- Utility functions
- UI component props

### Integration Tests
- Page-level interactions
- Store updates trigger UI changes
- Routing navigation

### E2E Tests
- Critical user flows
- Search & filter
- Create/edit operations

---

## Migration Path: Mock → API

### Current State
```typescript
constructor() {
  makeAutoObservable(this)
  this.loadMockData() // ← Hardcoded data
}
```

### Future State
```typescript
constructor() {
  makeAutoObservable(this)
}

// Called on mount
async fetchContacts() {
  this.isLoading = true
  try {
    const res = await fetch('/api/contacts')
    runInAction(() => {
      this.contacts = await res.json()
      this.isLoading = false
    })
  } catch (error) {
    runInAction(() => {
      this.error = error
      this.isLoading = false
    })
  }
}

// Actions become async
async selectContact(id: string) {
  this.isLoading = true
  const res = await fetch(`/api/contacts/${id}`)
  const contact = await res.json()
  runInAction(() => {
    this.selectedContact = contact
    this.isLoading = false
  })
}
```

### WebSocket Integration (Real-time)

```typescript
// In RootStore constructor
connectWebSocket() {
  this.socket = new WebSocket('ws://api.example.com')

  this.socket.on('deal:updated', (data) => {
    runInAction(() => {
      const deal = this.dealsStore.deals.find(d => d.id === data.id)
      if (deal) Object.assign(deal, data.changes)
    })
  })

  this.socket.on('message:received', (message) => {
    runInAction(() => {
      const conv = this.messagesStore.conversations.find(
        c => c.id === message.conversationId
      )
      if (conv) {
        conv.messages.push(message)
        conv.unreadCount++
      }
    })
  })
}
```

---

## Build & Development

### Development
```bash
npm run dev  # Vite dev server on localhost:5173
```

### Build
```bash
npm run build  # TypeScript check + Vite build → dist/
```

### Environment Variables (Future)
```
VITE_API_URL=https://api.flow.com
VITE_WS_URL=wss://api.flow.com
VITE_AI_SERVICE_URL=https://ai.flow.com
```

Access in code:
```typescript
const API_URL = import.meta.env.VITE_API_URL
```

---

## Summary

**Architecture Strengths**:
- Clean separation: Stores (logic) ↔ Components (UI)
- Type-safe throughout
- Reactive, minimal boilerplate
- Scalable structure
- Mock data allows frontend-first development

**Ready for Backend Integration**:
- All data models defined
- Store methods ready to become async
- UI fully functional with mock data
- Clear migration path

**Next Steps**:
1. Connect to backend API (replace mock data)
2. Add WebSocket for real-time updates
3. Implement error handling
4. Add loading states
5. Authentication flow
6. Production optimizations
