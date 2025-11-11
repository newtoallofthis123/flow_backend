# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FlowApi.Repo.insert!(%FlowApi.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias FlowApi.{Accounts, Contacts, Deals, Messages, Calendar, Repo}

# Create test user
{:ok, user} = Accounts.create_user(%{
  email: "test@example.com",
  password: "password123",
  name: "Test User",
  role: "sales"
})

IO.puts("Created user: #{user.email}")

# Create test contacts
{:ok, contact1} = Contacts.create_contact(user.id, %{
  name: "John Doe",
  email: "john@example.com",
  company: "Acme Corp",
  title: "CEO",
  health_score: 85,
  relationship_health: "high"
})

{:ok, contact2} = Contacts.create_contact(user.id, %{
  name: "Jane Smith",
  email: "jane@example.com",
  company: "Tech Solutions Inc",
  title: "VP of Sales",
  health_score: 72,
  relationship_health: "medium"
})

{:ok, contact3} = Contacts.create_contact(user.id, %{
  name: "Bob Johnson",
  email: "bob@example.com",
  company: "StartupXYZ",
  title: "Founder",
  health_score: 45,
  relationship_health: "low",
  churn_risk: 75
})

IO.puts("Created #{length([contact1, contact2, contact3])} contacts")

# Create test deals
{:ok, deal1} = Deals.create_deal(user.id, %{
  title: "Acme Corp - Enterprise Package",
  contact_id: contact1.id,
  company: "Acme Corp",
  value: Decimal.new("50000"),
  stage: "proposal",
  probability: 75,
  confidence: "high",
  priority: "high",
  expected_close_date: ~D[2025-12-15]
})

{:ok, deal2} = Deals.create_deal(user.id, %{
  title: "Tech Solutions - Annual Contract",
  contact_id: contact2.id,
  company: "Tech Solutions Inc",
  value: Decimal.new("30000"),
  stage: "negotiation",
  probability: 60,
  confidence: "medium",
  priority: "medium",
  expected_close_date: ~D[2025-11-30]
})

{:ok, deal3} = Deals.create_deal(user.id, %{
  title: "StartupXYZ - Pilot Program",
  contact_id: contact3.id,
  company: "StartupXYZ",
  value: Decimal.new("10000"),
  stage: "qualified",
  probability: 40,
  confidence: "low",
  priority: "low",
  expected_close_date: ~D[2026-01-15]
})

IO.puts("Created #{length([deal1, deal2, deal3])} deals")

# Create test conversations
{:ok, conversation1} = Repo.insert(%FlowApi.Messages.Conversation{
  user_id: user.id,
  contact_id: contact1.id,
  last_message_at: DateTime.utc_now(),
  unread_count: 2,
  overall_sentiment: "positive",
  priority: "high"
})

{:ok, conversation2} = Repo.insert(%FlowApi.Messages.Conversation{
  user_id: user.id,
  contact_id: contact2.id,
  last_message_at: DateTime.utc_now() |> DateTime.add(-3600, :second),
  unread_count: 0,
  overall_sentiment: "neutral",
  priority: "medium"
})

IO.puts("Created #{length([conversation1, conversation2])} conversations")

# Create test calendar events
{:ok, event1} = Calendar.create_event(user.id, %{
  title: "Meeting with John Doe",
  contact_id: contact1.id,
  deal_id: deal1.id,
  start_time: DateTime.utc_now() |> DateTime.add(86400, :second),
  end_time: DateTime.utc_now() |> DateTime.add(90000, :second),
  type: "meeting",
  status: "scheduled",
  priority: "high"
})

{:ok, event2} = Calendar.create_event(user.id, %{
  title: "Follow-up call with Jane",
  contact_id: contact2.id,
  start_time: DateTime.utc_now() |> DateTime.add(172800, :second),
  end_time: DateTime.utc_now() |> DateTime.add(173400, :second),
  type: "call",
  status: "scheduled",
  priority: "medium"
})

IO.puts("Created #{length([event1, event2])} calendar events")

IO.puts("\n✅ Seed data created successfully!")
IO.puts("You can now login with:")
IO.puts("  Email: test@example.com")
IO.puts("  Password: password123")
