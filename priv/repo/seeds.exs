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
alias FlowApi.Contacts.{Contact, CommunicationEvent, AIInsight}

# Create user "noob"
{:ok, user} = Accounts.create_user(%{
  email: "noob@flow.com",
  password: "password123",
  name: "noob",
  role: "sales"
})

IO.puts("Created user: #{user.email}")

# Create first contact with history
{:ok, contact1} = Contacts.create_contact(user.id, %{
  name: "Sarah Johnson",
  email: "sarah.johnson@techcorp.com",
  phone: "+1-555-0123",
  company: "TechCorp Industries",
  title: "VP of Engineering",
  health_score: 85,
  relationship_health: "high",
  sentiment: "positive",
  churn_risk: 15,
  last_contact_at: DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:second),
  next_follow_up_at: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second),
  notes: "Key decision maker for enterprise software purchases. Very engaged and responsive."
})

# Create communication history for contact 1
{:ok, _comm1} = Repo.insert(%CommunicationEvent{
  contact_id: contact1.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second),
  subject: "Initial Discovery Call",
  summary: "Discussed their current pain points with legacy CRM system. They're looking for a modern solution with AI capabilities.",
  sentiment: "positive",
  ai_analysis: "Strong interest shown. Budget allocated for Q4. Decision timeline: 2-3 months."
})

{:ok, _comm2} = Repo.insert(%CommunicationEvent{
  contact_id: contact1.id,
  user_id: user.id,
  type: "email",
  occurred_at: DateTime.utc_now() |> DateTime.add(-15, :day) |> DateTime.truncate(:second),
  subject: "Product Demo Follow-up",
  summary: "Sent detailed proposal and pricing. Sarah shared it with her team and CFO.",
  sentiment: "positive",
  ai_analysis: "Positive engagement. Multiple stakeholders now involved. Moving to evaluation phase."
})

{:ok, _comm3} = Repo.insert(%CommunicationEvent{
  contact_id: contact1.id,
  user_id: user.id,
  type: "call",
  occurred_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  subject: "Technical Requirements Discussion",
  summary: "45-minute call covering integration requirements, security compliance, and implementation timeline.",
  sentiment: "positive",
  ai_analysis: "Deal progressing well. Technical validation phase. Some concerns about data migration addressed."
})

{:ok, _comm4} = Repo.insert(%CommunicationEvent{
  contact_id: contact1.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:second),
  subject: "Executive Stakeholder Meeting",
  summary: "Met with Sarah and CFO to discuss contract terms and ROI projections.",
  sentiment: "positive",
  ai_analysis: "Strong buying signals. CFO approved budget. Expect contract signing within 2 weeks."
})

# Create AI insights for contact 1
{:ok, _insight1} = Repo.insert(%AIInsight{
  contact_id: contact1.id,
  insight_type: "opportunity",
  title: "High Probability Close",
  description: "Based on engagement patterns and stakeholder involvement, this deal has an 85% probability of closing within the next 2 weeks.",
  confidence: 85,
  actionable: true,
  suggested_action: "Schedule contract review meeting with legal team. Prepare implementation kickoff materials."
})

{:ok, _insight2} = Repo.insert(%AIInsight{
  contact_id: contact1.id,
  insight_type: "trend",
  title: "Increasing Engagement",
  description: "Communication frequency has increased 40% over the past month. Response time averaging under 4 hours.",
  confidence: 92,
  actionable: false,
  suggested_action: nil
})

{:ok, _insight3} = Repo.insert(%AIInsight{
  contact_id: contact1.id,
  insight_type: "suggestion",
  title: "Upsell Opportunity",
  description: "Contact mentioned expanding to 3 additional departments in 6 months. Consider presenting enterprise tier benefits.",
  confidence: 78,
  actionable: true,
  suggested_action: "Prepare enterprise tier comparison and ROI analysis for multi-department deployment."
})

IO.puts("Created contact 1 with communication history and AI insights")

# Create second contact with history
{:ok, contact2} = Contacts.create_contact(user.id, %{
  name: "Michael Chen",
  email: "m.chen@innovatestart.io",
  phone: "+1-555-0456",
  company: "InnovateStart",
  title: "Founder & CEO",
  health_score: 55,
  relationship_health: "medium",
  sentiment: "neutral",
  churn_risk: 45,
  last_contact_at: DateTime.utc_now() |> DateTime.add(-14, :day) |> DateTime.truncate(:second),
  next_follow_up_at: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second),
  notes: "Fast-growing startup. Budget-conscious but interested in growth tools. May need nurturing."
})

# Create communication history for contact 2
{:ok, _comm5} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "email",
  occurred_at: DateTime.utc_now() |> DateTime.add(-45, :day) |> DateTime.truncate(:second),
  subject: "Introduction via LinkedIn",
  summary: "Initial outreach after connecting on LinkedIn. Michael expressed interest in learning more about our platform.",
  sentiment: "neutral",
  ai_analysis: "Cold lead showing mild interest. Startup in early growth phase. Budget may be limited."
})

{:ok, _comm6} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "call",
  occurred_at: DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second),
  subject: "Product Overview Call",
  summary: "20-minute intro call. Michael is interested but concerned about pricing. Currently using free tools.",
  sentiment: "neutral",
  ai_analysis: "Price sensitivity detected. Startup budget constraints. May need startup-friendly pricing or trial period."
})

{:ok, _comm7} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "email",
  occurred_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second),
  subject: "Startup Program Information",
  summary: "Sent information about our startup discount program and flexible payment options.",
  sentiment: "positive",
  ai_analysis: "Positive response to startup program. Interest level increased. Requested demo for his team."
})

{:ok, _comm8} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-14, :day) |> DateTime.truncate(:second),
  subject: "Team Demo Session",
  summary: "Demo with Michael and 2 team members. Good engagement but mentioned they need to close current funding round first.",
  sentiment: "neutral",
  ai_analysis: "Timing issue identified. Waiting on funding. Follow up in 2-3 weeks. Keep relationship warm."
})

{:ok, _comm9} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "note",
  occurred_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  subject: "LinkedIn Activity",
  summary: "Michael posted about closing Series A funding round. Good timing to reach out.",
  sentiment: "positive",
  ai_analysis: "Funding secured. Budget constraints likely resolved. High priority for immediate follow-up."
})

# Create AI insights for contact 2
{:ok, _insight4} = Repo.insert(%AIInsight{
  contact_id: contact2.id,
  insight_type: "opportunity",
  title: "Re-engagement Window",
  description: "Contact recently secured Series A funding. Budget constraints removed. Optimal time to re-engage with proposal.",
  confidence: 82,
  actionable: true,
  suggested_action: "Send congratulations message and schedule follow-up call to discuss implementation timeline."
})

{:ok, _insight5} = Repo.insert(%AIInsight{
  contact_id: contact2.id,
  insight_type: "risk",
  title: "Engagement Declining",
  description: "No contact in 14 days. Response time increased from 2 hours to 5 days. Risk of going cold.",
  confidence: 68,
  actionable: true,
  suggested_action: "Immediate outreach required. Reference recent funding news and offer congratulations. Propose specific next steps."
})

{:ok, _insight6} = Repo.insert(%AIInsight{
  contact_id: contact2.id,
  insight_type: "suggestion",
  title: "Startup Success Story",
  description: "Share case study of similar startup that scaled successfully using our platform. Resonates with growth-stage companies.",
  confidence: 75,
  actionable: true,
  suggested_action: "Send relevant case study highlighting ROI and time-to-value for early-stage companies."
})

IO.puts("Created contact 2 with communication history and AI insights")

# Create test deals
{:ok, deal1} = Deals.create_deal(user.id, %{
  title: "TechCorp Industries - Enterprise Package",
  contact_id: contact1.id,
  company: "TechCorp Industries",
  value: Decimal.new("75000"),
  stage: "proposal",
  probability: 85,
  confidence: "high",
  priority: "high",
  expected_close_date: ~D[2025-11-25]
})

{:ok, deal2} = Deals.create_deal(user.id, %{
  title: "InnovateStart - Startup Growth Plan",
  contact_id: contact2.id,
  company: "InnovateStart",
  value: Decimal.new("15000"),
  stage: "qualified",
  probability: 55,
  confidence: "medium",
  priority: "medium",
  expected_close_date: ~D[2025-12-15]
})

IO.puts("Created #{length([deal1, deal2])} deals")

# Create test conversations
{:ok, conversation1} = Repo.insert(%FlowApi.Messages.Conversation{
  user_id: user.id,
  contact_id: contact1.id,
  last_message_at: DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:second),
  unread_count: 1,
  overall_sentiment: "positive",
  priority: "high"
})

{:ok, conversation2} = Repo.insert(%FlowApi.Messages.Conversation{
  user_id: user.id,
  contact_id: contact2.id,
  last_message_at: DateTime.utc_now() |> DateTime.add(-14, :day) |> DateTime.truncate(:second),
  unread_count: 0,
  overall_sentiment: "neutral",
  priority: "medium"
})

IO.puts("Created #{length([conversation1, conversation2])} conversations")

# Create test calendar events
{:ok, event1} = Calendar.create_event(user.id, %{
  title: "Contract Review with Sarah",
  contact_id: contact1.id,
  deal_id: deal1.id,
  start_time: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second),
  end_time: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
  type: "meeting",
  status: "scheduled",
  priority: "high"
})

{:ok, event2} = Calendar.create_event(user.id, %{
  title: "Follow-up Call with Michael",
  contact_id: contact2.id,
  start_time: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second),
  end_time: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.add(1800, :second) |> DateTime.truncate(:second),
  type: "call",
  status: "scheduled",
  priority: "medium"
})

IO.puts("Created #{length([event1, event2])} calendar events")

IO.puts("\n✅ Seed data created successfully!")
IO.puts("=" |> String.duplicate(50))
IO.puts("User created:")
IO.puts("  Email: noob@flow.com")
IO.puts("  Password: password123")
IO.puts("  Name: noob")
IO.puts("")
IO.puts("Contacts created:")
IO.puts("  1. Sarah Johnson (TechCorp Industries) - High engagement, 85% close probability")
IO.puts("     - 4 communication events (meetings, calls, emails)")
IO.puts("     - 3 AI insights (opportunity, trend, suggestion)")
IO.puts("")
IO.puts("  2. Michael Chen (InnovateStart) - Medium engagement, needs follow-up")
IO.puts("     - 5 communication events (emails, calls, meeting, note)")
IO.puts("     - 3 AI insights (opportunity, risk, suggestion)")
IO.puts("=" |> String.duplicate(50))
