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

alias FlowApi.{Accounts, Contacts, Deals, Messages, Calendar, Repo, Dashboard}
alias FlowApi.Contacts.{Contact, CommunicationEvent, AIInsight}
alias FlowApi.Deals.{Deal, Activity, Insight, Signal}
alias FlowApi.Messages.{Conversation, Message, MessageAnalysis, Attachment}
alias FlowApi.Calendar.{Event, MeetingPreparation, MeetingOutcome, MeetingInsight, Attendee, EventAttendee}
alias FlowApi.Tags.{Tag, Tagging}
alias FlowApi.Dashboard.ActionItem

IO.puts("\n🌱 Starting seed process...\n")

# ============================================================================
# USERS
# ============================================================================
IO.puts("Creating user...")
user = case Accounts.create_user(%{
  email: "noob@flow.com",
  password: "password123",
  name: "noob",
  role: "sales"
}) do
  {:ok, user} -> user
  {:error, _changeset} ->
    # User already exists, fetch it
    Repo.get_by!(FlowApi.Accounts.User, email: "noob@flow.com")
end
IO.puts("✓ User ready: #{user.email}")

# ============================================================================
# TAGS
# ============================================================================
IO.puts("\nCreating tags...")

# Helper function to get or create tag
get_or_create_tag = fn name, color ->
  case Repo.get_by(Tag, name: name) do
    nil -> Repo.insert!(%Tag{name: name, color: color})
    tag -> tag
  end
end

tag_hot = get_or_create_tag.("Hot Lead", "#FF4444")
tag_enterprise = get_or_create_tag.("Enterprise", "#4169E1")
tag_startup = get_or_create_tag.("Startup", "#32CD32")
tag_urgent = get_or_create_tag.("Urgent", "#FF8C00")
tag_demo = get_or_create_tag.("Demo Scheduled", "#9370DB")
tag_contract = get_or_create_tag.("Contract Review", "#FFD700")
IO.puts("✓ Created/loaded 6 tags")

# ============================================================================
# CONTACT 1: Sarah Johnson (High-value, closing soon)
# ============================================================================
IO.puts("\n📇 Creating Contact 1: Sarah Johnson (TechCorp Industries)...")
{:ok, contact1} = Contacts.create_contact(user.id, %{
  name: "Sarah Johnson",
  email: "sarah.johnson@techcorp.com",
  phone: "+1-555-0123",
  company: "TechCorp Industries",
  title: "VP of Engineering",
  health_score: 88,
  relationship_health: "high",
  sentiment: "positive",
  churn_risk: 12,
  last_contact_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second),
  next_follow_up_at: DateTime.utc_now() |> DateTime.add(2, :day) |> DateTime.truncate(:second),
  notes: "Key decision maker for enterprise software purchases. Very engaged and responsive. CFO approved budget."
})

# Tag contact 1
Repo.insert!(%Tagging{tag_id: tag_hot.id, taggable_id: contact1.id, taggable_type: "Contact"})
Repo.insert!(%Tagging{tag_id: tag_enterprise.id, taggable_id: contact1.id, taggable_type: "Contact"})
Repo.insert!(%Tagging{tag_id: tag_contract.id, taggable_id: contact1.id, taggable_type: "Contact"})

# Communication Events for Contact 1
{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact1.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second),
  subject: "Initial Discovery Call",
  summary: "Discussed their current pain points with legacy CRM system. They're looking for a modern solution with AI capabilities.",
  sentiment: "positive",
  ai_analysis: "Strong interest shown. Budget allocated for Q4. Decision timeline: 2-3 months."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact1.id,
  user_id: user.id,
  type: "email",
  occurred_at: DateTime.utc_now() |> DateTime.add(-22, :day) |> DateTime.truncate(:second),
  subject: "Product Demo Follow-up",
  summary: "Sent detailed proposal and pricing. Sarah shared it with her team and CFO.",
  sentiment: "positive",
  ai_analysis: "Positive engagement. Multiple stakeholders now involved. Moving to evaluation phase."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact1.id,
  user_id: user.id,
  type: "call",
  occurred_at: DateTime.utc_now() |> DateTime.add(-15, :day) |> DateTime.truncate(:second),
  subject: "Technical Requirements Discussion",
  summary: "45-minute call covering integration requirements, security compliance, and implementation timeline.",
  sentiment: "positive",
  ai_analysis: "Deal progressing well. Technical validation phase. Some concerns about data migration addressed."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact1.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  subject: "Executive Stakeholder Meeting",
  summary: "Met with Sarah and CFO to discuss contract terms and ROI projections.",
  sentiment: "positive",
  ai_analysis: "Strong buying signals. CFO approved budget. Expect contract signing within 2 weeks."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact1.id,
  user_id: user.id,
  type: "email",
  occurred_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second),
  subject: "Contract Draft Sent",
  summary: "Sent final contract for legal review. Sarah confirmed their team is reviewing it.",
  sentiment: "positive",
  ai_analysis: "Deal in final stages. Legal review in progress. High confidence close within 7 days."
})

# AI Insights for Contact 1
{:ok, _} = Repo.insert(%AIInsight{
  contact_id: contact1.id,
  insight_type: "opportunity",
  title: "High Probability Close",
  description: "Based on engagement patterns and stakeholder involvement, this deal has a 90% probability of closing within the next week.",
  confidence: 90,
  actionable: true,
  suggested_action: "Prepare implementation kickoff materials. Schedule onboarding call for next week."
})

{:ok, _} = Repo.insert(%AIInsight{
  contact_id: contact1.id,
  insight_type: "trend",
  title: "Increasing Engagement",
  description: "Communication frequency has increased 40% over the past month. Response time averaging under 4 hours.",
  confidence: 92,
  actionable: false,
  suggested_action: nil
})

{:ok, _} = Repo.insert(%AIInsight{
  contact_id: contact1.id,
  insight_type: "suggestion",
  title: "Upsell Opportunity",
  description: "Contact mentioned expanding to 3 additional departments in 6 months. Consider presenting enterprise tier benefits.",
  confidence: 78,
  actionable: true,
  suggested_action: "Prepare enterprise tier comparison and ROI analysis for multi-department deployment."
})

IO.puts("✓ Created contact 1 with 5 communication events and 3 AI insights")

# ============================================================================
# CONTACT 2: Michael Chen (Startup, re-engagement opportunity)
# ============================================================================
IO.puts("\n📇 Creating Contact 2: Michael Chen (InnovateStart)...")
{:ok, contact2} = Contacts.create_contact(user.id, %{
  name: "Michael Chen",
  email: "m.chen@innovatestart.io",
  phone: "+1-555-0456",
  company: "InnovateStart",
  title: "Founder & CEO",
  health_score: 62,
  relationship_health: "medium",
  sentiment: "positive",
  churn_risk: 38,
  last_contact_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  next_follow_up_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second),
  notes: "Fast-growing startup. Just closed Series A funding. Budget constraints removed. Ready to scale."
})

# Tag contact 2
Repo.insert!(%Tagging{tag_id: tag_startup.id, taggable_id: contact2.id, taggable_type: "Contact"})
Repo.insert!(%Tagging{tag_id: tag_urgent.id, taggable_id: contact2.id, taggable_type: "Contact"})

# Communication Events for Contact 2
{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "email",
  occurred_at: DateTime.utc_now() |> DateTime.add(-45, :day) |> DateTime.truncate(:second),
  subject: "Introduction via LinkedIn",
  summary: "Initial outreach after connecting on LinkedIn. Michael expressed interest in learning more about our platform.",
  sentiment: "neutral",
  ai_analysis: "Cold lead showing mild interest. Startup in early growth phase. Budget may be limited."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "call",
  occurred_at: DateTime.utc_now() |> DateTime.add(-35, :day) |> DateTime.truncate(:second),
  subject: "Product Overview Call",
  summary: "20-minute intro call. Michael is interested but concerned about pricing. Currently using free tools.",
  sentiment: "neutral",
  ai_analysis: "Price sensitivity detected. Startup budget constraints. May need startup-friendly pricing or trial period."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "email",
  occurred_at: DateTime.utc_now() |> DateTime.add(-28, :day) |> DateTime.truncate(:second),
  subject: "Startup Program Information",
  summary: "Sent information about our startup discount program and flexible payment options.",
  sentiment: "positive",
  ai_analysis: "Positive response to startup program. Interest level increased. Requested demo for his team."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second),
  subject: "Team Demo Session",
  summary: "Demo with Michael and 2 team members. Good engagement but mentioned they need to close current funding round first.",
  sentiment: "neutral",
  ai_analysis: "Timing issue identified. Waiting on funding. Follow up in 2-3 weeks. Keep relationship warm."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact2.id,
  user_id: user.id,
  type: "note",
  occurred_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  subject: "LinkedIn Activity - Series A Closed",
  summary: "Michael posted about closing Series A funding round ($5M). Good timing to reach out.",
  sentiment: "positive",
  ai_analysis: "Funding secured. Budget constraints likely resolved. High priority for immediate follow-up."
})

# AI Insights for Contact 2
{:ok, _} = Repo.insert(%AIInsight{
  contact_id: contact2.id,
  insight_type: "opportunity",
  title: "Re-engagement Window",
  description: "Contact recently secured Series A funding. Budget constraints removed. Optimal time to re-engage with proposal.",
  confidence: 85,
  actionable: true,
  suggested_action: "Send congratulations message and schedule follow-up call to discuss implementation timeline."
})

{:ok, _} = Repo.insert(%AIInsight{
  contact_id: contact2.id,
  insight_type: "risk",
  title: "Timing is Critical",
  description: "Post-funding is optimal buying window. Competitors likely reaching out. Need to act within 7 days.",
  confidence: 78,
  actionable: true,
  suggested_action: "Immediate outreach required. Reference recent funding news. Propose specific next steps with urgency."
})

{:ok, _} = Repo.insert(%AIInsight{
  contact_id: contact2.id,
  insight_type: "suggestion",
  title: "Startup Success Story",
  description: "Share case study of similar startup that scaled successfully using our platform. Resonates with growth-stage companies.",
  confidence: 75,
  actionable: true,
  suggested_action: "Send relevant case study highlighting ROI and time-to-value for early-stage companies."
})

IO.puts("✓ Created contact 2 with 5 communication events and 3 AI insights")

# ============================================================================
# CONTACT 3: Jennifer Martinez (Large enterprise, long sales cycle)
# ============================================================================
IO.puts("\n📇 Creating Contact 3: Jennifer Martinez (Global Systems Corp)...")
{:ok, contact3} = Contacts.create_contact(user.id, %{
  name: "Jennifer Martinez",
  email: "j.martinez@globalsystems.com",
  phone: "+1-555-0789",
  company: "Global Systems Corp",
  title: "Chief Technology Officer",
  health_score: 45,
  relationship_health: "medium",
  sentiment: "neutral",
  churn_risk: 55,
  last_contact_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second),
  next_follow_up_at: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second),
  notes: "Large enterprise deal. Multiple stakeholders. Long decision process. Evaluating 3 vendors including us."
})

# Tag contact 3
Repo.insert!(%Tagging{tag_id: tag_enterprise.id, taggable_id: contact3.id, taggable_type: "Contact"})

# Communication Events for Contact 3
{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact3.id,
  user_id: user.id,
  type: "email",
  occurred_at: DateTime.utc_now() |> DateTime.add(-60, :day) |> DateTime.truncate(:second),
  subject: "RFP Response Submitted",
  summary: "Submitted comprehensive RFP response for their CRM modernization project.",
  sentiment: "neutral",
  ai_analysis: "Large enterprise opportunity. Competitive landscape. Need to differentiate on AI capabilities."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact3.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-45, :day) |> DateTime.truncate(:second),
  subject: "Initial Vendor Presentation",
  summary: "1-hour presentation to evaluation committee (6 stakeholders). Good questions about scalability and security.",
  sentiment: "neutral",
  ai_analysis: "Committee cautiously interested. Security and compliance are top priorities. Need to address data residency concerns."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact3.id,
  user_id: user.id,
  type: "call",
  occurred_at: DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second),
  subject: "Security & Compliance Deep Dive",
  summary: "Technical call with their security team. Discussed SOC 2, GDPR, and data encryption.",
  sentiment: "positive",
  ai_analysis: "Security concerns adequately addressed. Positive feedback from security team. Moving forward in evaluation."
})

{:ok, _} = Repo.insert(%CommunicationEvent{
  contact_id: contact3.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second),
  subject: "Proof of Concept Discussion",
  summary: "Discussed POC parameters. They want to evaluate with pilot group of 50 users for 30 days.",
  sentiment: "neutral",
  ai_analysis: "Deal slowing down. POC requested indicates they're not ready to commit. Competitor may be leading. Need to accelerate."
})

# AI Insights for Contact 3
{:ok, _} = Repo.insert(%AIInsight{
  contact_id: contact3.id,
  insight_type: "risk",
  title: "Deal Stalling",
  description: "No contact in 3 weeks. POC request suggests they're not convinced. May be favoring competitor.",
  confidence: 72,
  actionable: true,
  suggested_action: "Schedule executive alignment call. Understand true objections. Offer expedited POC with success metrics."
})

{:ok, _} = Repo.insert(%AIInsight{
  contact_id: contact3.id,
  insight_type: "suggestion",
  title: "Executive Sponsor Needed",
  description: "Large enterprise deals require executive sponsorship. Need to engage C-level champion.",
  confidence: 88,
  actionable: true,
  suggested_action: "Request introduction to CEO or President. Position as strategic partnership, not vendor relationship."
})

IO.puts("✓ Created contact 3 with 4 communication events and 2 AI insights")

# ============================================================================
# DEALS
# ============================================================================
IO.puts("\n💰 Creating deals...")

# Deal 1: TechCorp (High value, closing soon)
{:ok, deal1} = Deals.create_deal(user.id, %{
  title: "TechCorp Industries - Enterprise Package",
  contact_id: contact1.id,
  company: "TechCorp Industries",
  value: Decimal.new("85000"),
  stage: "negotiation",
  probability: 90,
  confidence: "high",
  priority: "high",
  expected_close_date: Date.utc_today() |> Date.add(7),
  description: "Enterprise package with AI features for 200 users. Annual contract with quarterly payment terms."
})

# Tag deal 1
Repo.insert!(%Tagging{tag_id: tag_hot.id, taggable_id: deal1.id, taggable_type: "Deal"})
Repo.insert!(%Tagging{tag_id: tag_contract.id, taggable_id: deal1.id, taggable_type: "Deal"})

# Deal Activities for Deal 1
{:ok, _} = Repo.insert(%Activity{
  deal_id: deal1.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  description: "Executive stakeholder meeting with CFO and VP Engineering",
  outcome: "positive",
  next_step: "Legal review of contract"
})

{:ok, _} = Repo.insert(%Activity{
  deal_id: deal1.id,
  user_id: user.id,
  type: "email",
  occurred_at: DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second),
  description: "Sent final pricing and contract terms",
  outcome: "positive",
  next_step: "Awaiting legal approval"
})

{:ok, _} = Repo.insert(%Activity{
  deal_id: deal1.id,
  user_id: user.id,
  type: "call",
  occurred_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second),
  description: "Contract clarification call with Sarah",
  outcome: "positive",
  next_step: "Final signature expected in 3-5 days"
})

# Deal Insights for Deal 1
{:ok, _} = Repo.insert(%Insight{
  deal_id: deal1.id,
  insight_type: "opportunity",
  title: "Ready to Close",
  description: "All stakeholders aligned. Contract in legal review. Strong buying signals indicate close within 7 days.",
  impact: "high",
  actionable: true,
  suggested_action: "Prepare onboarding materials. Schedule kickoff call for next week.",
  confidence: 92
})

{:ok, _} = Repo.insert(%Insight{
  deal_id: deal1.id,
  insight_type: "upsell",
  title: "Expansion Potential",
  description: "Contact mentioned 3 additional departments interested after initial rollout. Potential for 3x expansion in Q2.",
  impact: "high",
  actionable: true,
  suggested_action: "Include expansion terms in contract. Prepare enterprise success plan.",
  confidence: 78
})

# Deal Signals for Deal 1
{:ok, _} = Repo.insert(%Signal{
  deal_id: deal1.id,
  type: "engagement",
  signal: "Executive stakeholder involvement increased",
  confidence: 95,
  detected_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%Signal{
  deal_id: deal1.id,
  type: "budget",
  signal: "CFO approved budget allocation",
  confidence: 98,
  detected_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%Signal{
  deal_id: deal1.id,
  type: "timeline",
  signal: "Contract review in progress - legal team engaged",
  confidence: 90,
  detected_at: DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second)
})

IO.puts("✓ Created deal 1 with 3 activities, 2 insights, and 3 signals")

# Deal 2: InnovateStart (Startup, good timing)
{:ok, deal2} = Deals.create_deal(user.id, %{
  title: "InnovateStart - Growth Plan",
  contact_id: contact2.id,
  company: "InnovateStart",
  value: Decimal.new("18000"),
  stage: "qualified",
  probability: 65,
  confidence: "medium",
  priority: "high",
  expected_close_date: Date.utc_today() |> Date.add(21),
  description: "Growth plan for 25 users. Recently funded Series A. Strong interest in AI automation features."
})

# Tag deal 2
Repo.insert!(%Tagging{tag_id: tag_startup.id, taggable_id: deal2.id, taggable_type: "Deal"})
Repo.insert!(%Tagging{tag_id: tag_urgent.id, taggable_id: deal2.id, taggable_type: "Deal"})
Repo.insert!(%Tagging{tag_id: tag_demo.id, taggable_id: deal2.id, taggable_type: "Deal"})

# Deal Activities for Deal 2
{:ok, _} = Repo.insert(%Activity{
  deal_id: deal2.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second),
  description: "Initial demo with founder and 2 team members",
  outcome: "positive",
  next_step: "Follow up after funding round"
})

{:ok, _} = Repo.insert(%Activity{
  deal_id: deal2.id,
  user_id: user.id,
  type: "note",
  occurred_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  description: "Series A funding closed - $5M raised",
  outcome: "positive",
  next_step: "Reach out to congratulate and re-engage"
})

# Deal Insights for Deal 2
{:ok, _} = Repo.insert(%Insight{
  deal_id: deal2.id,
  insight_type: "opportunity",
  title: "Post-Funding Window",
  description: "Optimal timing for engagement. Startups typically make purchasing decisions within 30 days of funding.",
  impact: "high",
  actionable: true,
  suggested_action: "Send congratulations and proposal within 48 hours. Emphasize fast time-to-value.",
  confidence: 85
})

{:ok, _} = Repo.insert(%Insight{
  deal_id: deal2.id,
  insight_type: "competitive",
  title: "Competitor Likely Engaged",
  description: "Funding announcements trigger competitor outreach. Need to move quickly to establish preferred vendor status.",
  impact: "medium",
  actionable: true,
  suggested_action: "Differentiate on AI capabilities and startup-friendly terms.",
  confidence: 70
})

# Deal Signals for Deal 2
{:ok, _} = Repo.insert(%Signal{
  deal_id: deal2.id,
  type: "budget",
  signal: "Series A funding secured - budget constraints removed",
  confidence: 95,
  detected_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%Signal{
  deal_id: deal2.id,
  type: "engagement",
  signal: "Positive demo engagement - requested pricing",
  confidence: 75,
  detected_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second)
})

IO.puts("✓ Created deal 2 with 2 activities, 2 insights, and 2 signals")

# Deal 3: Global Systems (Large enterprise, long cycle)
{:ok, deal3} = Deals.create_deal(user.id, %{
  title: "Global Systems Corp - Enterprise Transformation",
  contact_id: contact3.id,
  company: "Global Systems Corp",
  value: Decimal.new("250000"),
  stage: "proposal",
  probability: 40,
  confidence: "medium",
  priority: "medium",
  expected_close_date: Date.utc_today() |> Date.add(90),
  description: "Large enterprise CRM modernization. 500+ users. Multi-year contract. Competitive evaluation in progress."
})

# Tag deal 3
Repo.insert!(%Tagging{tag_id: tag_enterprise.id, taggable_id: deal3.id, taggable_type: "Deal"})

# Deal Activities for Deal 3
{:ok, _} = Repo.insert(%Activity{
  deal_id: deal3.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-45, :day) |> DateTime.truncate(:second),
  description: "Vendor presentation to evaluation committee",
  outcome: "neutral",
  next_step: "Technical deep dive on security"
})

{:ok, _} = Repo.insert(%Activity{
  deal_id: deal3.id,
  user_id: user.id,
  type: "call",
  occurred_at: DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second),
  description: "Security and compliance review with CISO",
  outcome: "positive",
  next_step: "POC discussion"
})

{:ok, _} = Repo.insert(%Activity{
  deal_id: deal3.id,
  user_id: user.id,
  type: "meeting",
  occurred_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second),
  description: "POC scope discussion",
  outcome: "neutral",
  next_step: "Waiting on their timeline"
})

# Deal Insights for Deal 3
{:ok, _} = Repo.insert(%Insight{
  deal_id: deal3.id,
  insight_type: "risk",
  title: "Deal Momentum Slowing",
  description: "3 weeks with no contact. POC request indicates lack of conviction. Competitor may be leading.",
  impact: "high",
  actionable: true,
  suggested_action: "Executive intervention needed. Request call with CTO to understand blockers.",
  confidence: 75
})

{:ok, _} = Repo.insert(%Insight{
  deal_id: deal3.id,
  insight_type: "strategy",
  title: "Need Executive Champion",
  description: "Large deals require internal champion at C-level. Current contact (CTO) is evaluating options but not advocating.",
  impact: "high",
  actionable: true,
  suggested_action: "Request introduction to CEO. Position as strategic partner, not vendor.",
  confidence: 82
})

# Deal Signals for Deal 3
{:ok, _} = Repo.insert(%Signal{
  deal_id: deal3.id,
  type: "risk",
  signal: "Communication frequency declining",
  confidence: 70,
  detected_at: DateTime.utc_now() |> DateTime.add(-14, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%Signal{
  deal_id: deal3.id,
  type: "competitive",
  signal: "POC request suggests competitive evaluation",
  confidence: 65,
  detected_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second)
})

IO.puts("✓ Created deal 3 with 3 activities, 2 insights, and 2 signals")

# ============================================================================
# CONVERSATIONS & MESSAGES
# ============================================================================
IO.puts("\n💬 Creating conversations and messages...")

# Conversation 1: Sarah Johnson (Recent, active)
{:ok, conversation1} = Repo.insert(%Conversation{
  user_id: user.id,
  contact_id: contact1.id,
  last_message_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second),
  unread_count: 1,
  overall_sentiment: "positive",
  sentiment_trend: "improving",
  ai_summary: "Contract review in progress. Legal team engaged. High confidence close expected within 7 days.",
  priority: "high"
})

# Tag conversation 1
Repo.insert!(%Tagging{tag_id: tag_hot.id, taggable_id: conversation1.id, taggable_type: "Conversation"})

# Messages for Conversation 1
{:ok, msg1_1} = Repo.insert(%Message{
  conversation_id: conversation1.id,
  sender_id: user.id,
  sender_name: "noob",
  sender_type: "user",
  content: "Hi Sarah, thanks for the great meeting yesterday! I've attached the final contract for your review. The terms we discussed are all reflected, including the quarterly payment schedule and the enterprise AI features package.",
  type: "email",
  subject: "Contract for TechCorp Enterprise Package",
  sentiment: "positive",
  confidence: 85,
  status: "read",
  sent_at: DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg1_1.id,
  key_topics: ["contract", "pricing", "terms", "enterprise package"],
  emotional_tone: "professional and enthusiastic",
  urgency_level: "medium",
  business_intent: "closing",
  suggested_response: nil,
  response_time: "responded within 4 hours",
  action_items: ["Review contract", "Obtain legal approval"]
})

{:ok, msg1_2} = Repo.insert(%Message{
  conversation_id: conversation1.id,
  sender_name: "Sarah Johnson",
  sender_type: "contact",
  content: "Thanks! I've forwarded this to our legal team. They're reviewing it now. I expect we'll have approval by end of week. Really excited to get started with the implementation!",
  type: "email",
  subject: "Re: Contract for TechCorp Enterprise Package",
  sentiment: "positive",
  confidence: 92,
  status: "sent",
  sent_at: DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.add(4, :hour) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg1_2.id,
  key_topics: ["legal review", "approval", "implementation", "timeline"],
  emotional_tone: "positive and enthusiastic",
  urgency_level: "low",
  business_intent: "buying signal",
  suggested_response: "Acknowledge timeline and prepare onboarding materials",
  response_time: nil,
  action_items: ["Prepare implementation kickoff materials", "Schedule onboarding call"]
})

{:ok, msg1_3} = Repo.insert(%Message{
  conversation_id: conversation1.id,
  sender_id: user.id,
  sender_name: "noob",
  sender_type: "user",
  content: "That's great to hear! I'll prepare the onboarding materials in the meantime. Let me know if your legal team has any questions - I'm happy to jump on a quick call to clarify anything.",
  type: "email",
  subject: "Re: Contract for TechCorp Enterprise Package",
  sentiment: "positive",
  confidence: 88,
  status: "read",
  sent_at: DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg1_3.id,
  key_topics: ["onboarding", "support", "availability"],
  emotional_tone: "supportive and proactive",
  urgency_level: "low",
  business_intent: "nurturing",
  suggested_response: nil,
  response_time: "responded within 1 day",
  action_items: ["Prepare onboarding materials", "Stand by for legal questions"]
})

{:ok, msg1_4} = Repo.insert(%Message{
  conversation_id: conversation1.id,
  sender_name: "Sarah Johnson",
  sender_type: "contact",
  content: "Quick update - our legal team had one question about data residency requirements for our European operations. Can you confirm that data can be stored in EU data centers?",
  type: "email",
  subject: "Re: Contract for TechCorp Enterprise Package",
  sentiment: "neutral",
  confidence: 75,
  status: "sent",
  sent_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg1_4.id,
  key_topics: ["legal question", "data residency", "EU compliance", "GDPR"],
  emotional_tone: "inquisitive and professional",
  urgency_level: "high",
  business_intent: "objection handling",
  suggested_response: "Immediate response required. Confirm EU data center options and GDPR compliance.",
  response_time: nil,
  action_items: ["Respond immediately about EU data residency", "Provide GDPR compliance documentation"]
})

# Additional messages for conversation 1
{:ok, msg1_5} = Repo.insert(%Message{
  conversation_id: conversation1.id,
  sender_id: user.id,
  sender_name: "noob",
  sender_type: "user",
  content: "Absolutely! We have dedicated EU data centers in Frankfurt and Dublin. All data for EU customers can be stored exclusively within EU regions to ensure full GDPR compliance. I'm attaching our data residency certification and compliance documentation.",
  type: "email",
  subject: "Re: Contract for TechCorp Enterprise Package",
  sentiment: "positive",
  confidence: 90,
  status: "read",
  sent_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.add(2, :hour) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg1_5.id,
  key_topics: ["EU data centers", "GDPR compliance", "data residency", "certification"],
  emotional_tone: "confident and reassuring",
  urgency_level: "high",
  business_intent: "objection resolution",
  suggested_response: nil,
  response_time: "responded within 2 hours - excellent",
  action_items: ["Await legal team approval"]
})

{:ok, msg1_6} = Repo.insert(%Message{
  conversation_id: conversation1.id,
  sender_name: "Sarah Johnson",
  sender_type: "contact",
  content: "Perfect! That's exactly what our legal team needed to hear. I'm forwarding this to them now. I'm confident we'll have everything signed off by Friday. Can we schedule a kickoff call for Monday next week?",
  type: "email",
  subject: "Re: Contract for TechCorp Enterprise Package",
  sentiment: "positive",
  confidence: 95,
  status: "sent",
  sent_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.add(4, :hour) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg1_6.id,
  key_topics: ["legal approval", "contract signing", "kickoff call", "timeline"],
  emotional_tone: "excited and committed",
  urgency_level: "medium",
  business_intent: "closing - strong buying signal",
  suggested_response: "Confirm kickoff meeting and prepare implementation materials",
  response_time: nil,
  action_items: ["Schedule kickoff call for Monday", "Prepare onboarding agenda", "Assign implementation team"]
})

{:ok, msg1_7} = Repo.insert(%Message{
  conversation_id: conversation1.id,
  sender_id: user.id,
  sender_name: "noob",
  sender_type: "user",
  content: "That's wonderful news, Sarah! I'll send you a calendar invite for Monday at 10 AM for our kickoff call. I'll include our implementation lead and success manager so you can meet the team. Looking forward to partnering with TechCorp!",
  type: "email",
  subject: "Re: Contract for TechCorp Enterprise Package",
  sentiment: "positive",
  confidence: 92,
  status: "delivered",
  sent_at: DateTime.utc_now() |> DateTime.add(-20, :hour) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg1_7.id,
  key_topics: ["kickoff meeting", "calendar invite", "implementation team", "partnership"],
  emotional_tone: "professional and enthusiastic",
  urgency_level: "low",
  business_intent: "relationship building",
  suggested_response: nil,
  response_time: "responded same day",
  action_items: ["Send calendar invite", "Brief implementation team", "Prepare kickoff agenda"]
})

IO.puts("✓ Created conversation 1 with 7 messages and analysis")

# Conversation 2: Michael Chen (Follow-up needed)
{:ok, conversation2} = Repo.insert(%Conversation{
  user_id: user.id,
  contact_id: contact2.id,
  last_message_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  unread_count: 0,
  overall_sentiment: "positive",
  sentiment_trend: "improving",
  ai_summary: "Series A funding closed. Budget constraints removed. Optimal re-engagement window. High priority follow-up needed.",
  priority: "high"
})

# Tag conversation 2
Repo.insert!(%Tagging{tag_id: tag_urgent.id, taggable_id: conversation2.id, taggable_type: "Conversation"})

# Messages for Conversation 2
{:ok, msg2_1} = Repo.insert(%Message{
  conversation_id: conversation2.id,
  sender_id: user.id,
  sender_name: "noob",
  sender_type: "user",
  content: "Hi Michael, thanks for the great demo session last week! I know you mentioned needing to close your funding round first. I'll follow up in a few weeks to see how things are progressing.",
  type: "email",
  subject: "Following up on InnovateStart Demo",
  sentiment: "positive",
  confidence: 80,
  status: "read",
  sent_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg2_1.id,
  key_topics: ["demo follow-up", "funding", "timeline"],
  emotional_tone: "patient and understanding",
  urgency_level: "low",
  business_intent: "nurturing",
  suggested_response: nil,
  response_time: nil,
  action_items: ["Follow up after funding round"]
})

{:ok, msg2_2} = Repo.insert(%Message{
  conversation_id: conversation2.id,
  sender_name: "Michael Chen",
  sender_type: "contact",
  content: "Sounds good! Really impressed with the platform. We'll definitely want to revisit this once our funding comes through. Talk soon!",
  type: "email",
  subject: "Re: Following up on InnovateStart Demo",
  sentiment: "positive",
  confidence: 85,
  status: "sent",
  sent_at: DateTime.utc_now() |> DateTime.add(-20, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg2_2.id,
  key_topics: ["interest confirmed", "timing", "positive feedback"],
  emotional_tone: "enthusiastic and genuine",
  urgency_level: "low",
  business_intent: "qualified interest",
  suggested_response: "Monitor for funding announcement and follow up immediately",
  response_time: nil,
  action_items: ["Set alert for funding announcement", "Prepare congratulations outreach"]
})

{:ok, msg2_3} = Repo.insert(%Message{
  conversation_id: conversation2.id,
  sender_id: user.id,
  sender_name: "noob",
  sender_type: "user",
  content: "Congratulations on closing your Series A! Saw the announcement on LinkedIn - huge milestone! I'd love to reconnect and discuss how we can help InnovateStart scale with your growth. Are you available for a quick call this week?",
  type: "email",
  subject: "Congrats on Series A! Let's reconnect",
  sentiment: "positive",
  confidence: 90,
  status: "delivered",
  sent_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg2_3.id,
  key_topics: ["congratulations", "funding", "re-engagement", "meeting request"],
  emotional_tone: "enthusiastic and celebratory",
  urgency_level: "high",
  business_intent: "re-engagement",
  suggested_response: "Follow up if no response within 48-72 hours",
  response_time: "no response yet - 7 days",
  action_items: ["Follow up within 2 days if no response", "Prepare proposal with startup pricing"]
})

# Additional messages for conversation 2
{:ok, msg2_4} = Repo.insert(%Message{
  conversation_id: conversation2.id,
  sender_name: "Michael Chen",
  sender_type: "contact",
  content: "Hey! Thanks so much! It's been a crazy few weeks. I'd love to chat - we're actually looking to implement a proper CRM now that we have the budget. How about Thursday at 2 PM?",
  type: "email",
  subject: "Re: Congrats on Series A! Let's reconnect",
  sentiment: "positive",
  confidence: 88,
  status: "sent",
  sent_at: DateTime.utc_now() |> DateTime.add(-6, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg2_4.id,
  key_topics: ["meeting acceptance", "CRM implementation", "budget available", "timeline"],
  emotional_tone: "eager and ready to buy",
  urgency_level: "high",
  business_intent: "strong buying signal - ready to purchase",
  suggested_response: "Confirm meeting immediately and prepare tailored proposal",
  response_time: "responded within 24 hours",
  action_items: ["Confirm Thursday 2 PM meeting", "Prepare startup pricing proposal", "Create implementation timeline"]
})

{:ok, msg2_5} = Repo.insert(%Message{
  conversation_id: conversation2.id,
  sender_id: user.id,
  sender_name: "noob",
  sender_type: "user",
  content: "Perfect! Thursday at 2 PM works great. I'll send you a Zoom link. I've also prepared a special startup package that includes everything you saw in the demo plus some additional features that'll help you scale. Really excited to partner with you on this growth phase!",
  type: "email",
  subject: "Re: Congrats on Series A! Let's reconnect",
  sentiment: "positive",
  confidence: 92,
  status: "read",
  sent_at: DateTime.utc_now() |> DateTime.add(-6, :day) |> DateTime.add(3, :hour) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg2_5.id,
  key_topics: ["meeting confirmed", "startup package", "pricing proposal", "partnership"],
  emotional_tone: "professional and enthusiastic",
  urgency_level: "high",
  business_intent: "closing",
  suggested_response: nil,
  response_time: "responded within 3 hours - excellent",
  action_items: ["Send Zoom link", "Prepare startup package details", "Create custom demo"]
})

{:ok, msg2_6} = Repo.insert(%Message{
  conversation_id: conversation2.id,
  sender_name: "Michael Chen",
  sender_type: "contact",
  content: "Awesome! Looking forward to it. Quick question - does your platform integrate with Slack and GitHub? Those are critical for our team.",
  type: "email",
  subject: "Re: Congrats on Series A! Let's reconnect",
  sentiment: "positive",
  confidence: 85,
  status: "sent",
  sent_at: DateTime.utc_now() |> DateTime.add(-5, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg2_6.id,
  key_topics: ["integrations", "Slack", "GitHub", "technical requirements"],
  emotional_tone: "interested but doing due diligence",
  urgency_level: "medium",
  business_intent: "evaluation - addressing concerns",
  suggested_response: "Confirm integrations and highlight other tech stack integrations",
  response_time: nil,
  action_items: ["Confirm Slack and GitHub integrations", "Prepare integration documentation", "Show integration demos in call"]
})

{:ok, msg2_7} = Repo.insert(%Message{
  conversation_id: conversation2.id,
  sender_id: user.id,
  sender_name: "noob",
  sender_type: "user",
  content: "Great question! Yes, we have native integrations with both Slack and GitHub, plus 50+ other tools. I'll make sure to show you those integrations in our call on Thursday. You'll be able to get notifications, create tasks, and sync data seamlessly across your entire stack.",
  type: "email",
  subject: "Re: Congrats on Series A! Let's reconnect",
  sentiment: "positive",
  confidence: 88,
  status: "delivered",
  sent_at: DateTime.utc_now() |> DateTime.add(-5, :day) |> DateTime.add(1, :hour) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg2_7.id,
  key_topics: ["integrations confirmed", "Slack", "GitHub", "tech stack"],
  emotional_tone: "confident and informative",
  urgency_level: "medium",
  business_intent: "objection handling",
  suggested_response: nil,
  response_time: "responded within 1 hour - excellent",
  action_items: ["Prepare integration demo for Thursday call", "Create tech stack compatibility document"]
})

IO.puts("✓ Created conversation 2 with 7 messages and analysis")

# Conversation 3: Jennifer Martinez (Stalled, needs attention)
{:ok, conversation3} = Repo.insert(%Conversation{
  user_id: user.id,
  contact_id: contact3.id,
  last_message_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second),
  unread_count: 0,
  overall_sentiment: "neutral",
  sentiment_trend: "declining",
  ai_summary: "Deal stalling. POC requested. No contact in 3 weeks. Competitor may be leading. Executive intervention needed.",
  priority: "medium"
})

# Messages for Conversation 3
{:ok, msg3_1} = Repo.insert(%Message{
  conversation_id: conversation3.id,
  sender_id: user.id,
  sender_name: "noob",
  sender_type: "user",
  content: "Hi Jennifer, great meeting today discussing the POC. I've put together a proposed scope for a 30-day proof of concept with 50 users from your pilot team. Let me know if this aligns with your expectations.",
  type: "email",
  subject: "POC Proposal for Global Systems",
  sentiment: "positive",
  confidence: 75,
  status: "read",
  sent_at: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg3_1.id,
  key_topics: ["POC", "scope", "timeline", "pilot"],
  emotional_tone: "professional and accommodating",
  urgency_level: "medium",
  business_intent: "proposal",
  suggested_response: nil,
  response_time: "responded within 1 week",
  action_items: ["Wait for POC scope approval"]
})

{:ok, msg3_2} = Repo.insert(%Message{
  conversation_id: conversation3.id,
  sender_name: "Jennifer Martinez",
  sender_type: "contact",
  content: "Thanks for putting this together. The scope looks reasonable. I need to discuss timing with our team - we're in the middle of a datacenter migration project that's taking priority. I'll get back to you next week on potential POC start dates.",
  type: "email",
  subject: "Re: POC Proposal for Global Systems",
  sentiment: "neutral",
  confidence: 60,
  status: "sent",
  sent_at: DateTime.utc_now() |> DateTime.add(-14, :day) |> DateTime.truncate(:second)
})

{:ok, _} = Repo.insert(%MessageAnalysis{
  message_id: msg3_2.id,
  key_topics: ["delay", "timing concerns", "competing priorities", "datacenter migration"],
  emotional_tone: "non-committal and distracted",
  urgency_level: "medium",
  business_intent: "stalling",
  suggested_response: "Follow up in 1 week. Escalate if no response. Consider executive intervention.",
  response_time: nil,
  action_items: ["Follow up next week", "Prepare to escalate to executive level", "Understand true blockers"]
})

IO.puts("✓ Created conversation 3 with 2 messages and analysis")

# ============================================================================
# CALENDAR EVENTS
# ============================================================================
IO.puts("\n📅 Creating calendar events...")

# Create attendees
{:ok, attendee1} = Repo.insert(%Attendee{
  name: "Sarah Johnson",
  email: "sarah.johnson@techcorp.com",
  role: "VP of Engineering"
})

{:ok, attendee2} = Repo.insert(%Attendee{
  name: "Robert Williams",
  email: "r.williams@techcorp.com",
  role: "CFO"
})

{:ok, attendee3} = Repo.insert(%Attendee{
  name: "Michael Chen",
  email: "m.chen@innovatestart.io",
  role: "CEO"
})

{:ok, attendee4} = Repo.insert(%Attendee{
  name: "Jennifer Martinez",
  email: "j.martinez@globalsystems.com",
  role: "CTO"
})

# Event 1: Upcoming meeting with Sarah (future)
{:ok, event1} = Calendar.create_event(user.id, %{
  title: "Contract Review & Implementation Planning",
  contact_id: contact1.id,
  deal_id: deal1.id,
  description: "Final contract review and kickoff planning for TechCorp implementation",
  start_time: DateTime.utc_now() |> DateTime.add(2, :day) |> DateTime.truncate(:second),
  end_time: DateTime.utc_now() |> DateTime.add(2, :day) |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
  type: "meeting",
  location: "Virtual",
  meeting_link: "https://zoom.us/j/123456789",
  status: "confirmed",
  priority: "high"
})

# Tag event 1
Repo.insert!(%Tagging{tag_id: tag_hot.id, taggable_id: event1.id, taggable_type: "Event"})
Repo.insert!(%Tagging{tag_id: tag_contract.id, taggable_id: event1.id, taggable_type: "Event"})

# Add attendees to event 1
{:ok, _} = Repo.insert(%EventAttendee{
  event_id: event1.id,
  attendee_id: attendee1.id,
  status: "accepted"
})

# Meeting preparation for event 1
{:ok, _} = Repo.insert(%MeetingPreparation{
  event_id: event1.id,
  suggested_talking_points: [
    "Review final contract terms and payment schedule",
    "Discuss implementation timeline and milestones",
    "Identify key stakeholders for onboarding",
    "Address any remaining questions from legal review",
    "Confirm go-live date and success metrics"
  ],
  recent_interactions: [
    "Legal review in progress - data residency question pending",
    "CFO approved budget last week",
    "Sarah very enthusiastic about AI features",
    "3 additional departments interested for future expansion"
  ],
  deal_context: "Deal value: $85,000. Stage: Negotiation. Probability: 90%. Expected close in 7 days.",
  competitor_intel: [
    "Previously used Salesforce - found it too complex",
    "Evaluated HubSpot but concerned about AI limitations"
  ],
  personal_notes: [
    "Sarah prefers morning meetings (9-11am)",
    "Values data-driven decision making",
    "Strong relationship with CFO - key partnership"
  ],
  documents_to_share: [
    "Final contract PDF",
    "Implementation timeline",
    "Onboarding checklist",
    "GDPR & EU data residency documentation"
  ]
})

IO.puts("✓ Created event 1 with preparation notes")

# Event 2: Follow-up call with Michael (future)
{:ok, event2} = Calendar.create_event(user.id, %{
  title: "InnovateStart - Series A Follow-up",
  contact_id: contact2.id,
  deal_id: deal2.id,
  description: "Congratulations call and proposal discussion following Series A funding",
  start_time: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second),
  end_time: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.add(1800, :second) |> DateTime.truncate(:second),
  type: "call",
  meeting_link: "https://zoom.us/j/987654321",
  status: "scheduled",
  priority: "high"
})

# Tag event 2
Repo.insert!(%Tagging{tag_id: tag_urgent.id, taggable_id: event2.id, taggable_type: "Event"})
Repo.insert!(%Tagging{tag_id: tag_demo.id, taggable_id: event2.id, taggable_type: "Event"})

# Add attendees to event 2
{:ok, _} = Repo.insert(%EventAttendee{
  event_id: event2.id,
  attendee_id: attendee3.id,
  status: "tentative"
})

# Meeting preparation for event 2
{:ok, _} = Repo.insert(%MeetingPreparation{
  event_id: event2.id,
  suggested_talking_points: [
    "Congratulate on Series A funding milestone",
    "Review startup growth plan pricing and features",
    "Discuss implementation timeline (emphasize fast time-to-value)",
    "Address scalability as team grows",
    "Propose startup-friendly payment terms"
  ],
  recent_interactions: [
    "Positive demo 3 weeks ago with Michael and 2 team members",
    "Price sensitivity noted before funding",
    "Series A closed last week - $5M raised",
    "No response to congratulations email sent 7 days ago"
  ],
  deal_context: "Deal value: $18,000. Stage: Qualified. Probability: 65%. Expected close in 21 days.",
  competitor_intel: [
    "Currently using free tools (likely Notion + Airtable)",
    "Evaluating multiple CRM options",
    "Competitors likely reaching out post-funding"
  ],
  personal_notes: [
    "First-time founder, technical background",
    "Values automation and efficiency",
    "Team of 12, planning to double in 6 months"
  ],
  documents_to_share: [
    "Startup growth plan proposal",
    "Startup success case study",
    "Fast implementation guide (30-day timeline)",
    "Flexible payment terms sheet"
  ]
})

IO.puts("✓ Created event 2 with preparation notes")

# Event 3: Past meeting with Sarah (completed, with outcome)
{:ok, event3} = Calendar.create_event(user.id, %{
  title: "Executive Stakeholder Meeting - TechCorp",
  contact_id: contact1.id,
  deal_id: deal1.id,
  description: "Meeting with Sarah and CFO to discuss contract terms and ROI",
  start_time: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  end_time: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
  type: "meeting",
  status: "completed",
  priority: "high"
})

# Add attendees to event 3
{:ok, _} = Repo.insert(%EventAttendee{
  event_id: event3.id,
  attendee_id: attendee1.id,
  status: "accepted"
})

{:ok, _} = Repo.insert(%EventAttendee{
  event_id: event3.id,
  attendee_id: attendee2.id,
  status: "accepted"
})

# Meeting outcome for event 3
{:ok, _} = Repo.insert(%MeetingOutcome{
  event_id: event3.id,
  summary: "Excellent meeting with strong buying signals. CFO approved budget allocation ($85K) and confirmed quarterly payment terms work well for their fiscal planning. Sarah walked through her vision for AI-powered sales automation across 3 departments. They're excited about the predictive analytics features. Legal review is the final step before contract signing.",
  next_steps: [
    "Send final contract to legal team by end of week",
    "Prepare implementation kickoff materials",
    "Schedule onboarding call for week of 11/25",
    "Begin documenting requirements for future department expansion"
  ],
  sentiment_score: 85,
  key_decisions: [
    "CFO approved $85K budget",
    "Quarterly payment schedule confirmed",
    "Enterprise AI package selected",
    "Go-live target: December 15th",
    "Plan to expand to 3 additional departments in Q2"
  ],
  follow_up_required: true,
  follow_up_date: DateTime.utc_now() |> DateTime.add(2, :day) |> DateTime.truncate(:second),
  meeting_rating: 5
})

# Meeting insights for event 3
{:ok, _} = Repo.insert(%MeetingInsight{
  event_id: event3.id,
  insight_type: "opportunity",
  title: "Strong Buying Signals",
  description: "CFO budget approval and confirmed payment terms indicate high probability of close. Sarah's enthusiasm about expansion to 3 departments suggests 3x upsell potential in Q2.",
  confidence: 92,
  actionable: true,
  suggested_action: "Include expansion terms in contract. Position as strategic partnership for multi-department rollout."
})

{:ok, _} = Repo.insert(%MeetingInsight{
  event_id: event3.id,
  insight_type: "trend",
  title: "Executive Alignment",
  description: "Both VP Engineering and CFO present and aligned. This level of executive sponsorship significantly increases close probability.",
  confidence: 95,
  actionable: false,
  suggested_action: nil
})

IO.puts("✓ Created event 3 with outcome and insights")

# Event 4: Past demo with Michael (completed, with outcome)
{:ok, event4} = Calendar.create_event(user.id, %{
  title: "Team Demo - InnovateStart",
  contact_id: contact2.id,
  deal_id: deal2.id,
  description: "Product demo with Michael and team members",
  start_time: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.truncate(:second),
  end_time: DateTime.utc_now() |> DateTime.add(-21, :day) |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
  type: "demo",
  status: "completed",
  priority: "medium"
})

# Add attendees to event 4
{:ok, _} = Repo.insert(%EventAttendee{
  event_id: event4.id,
  attendee_id: attendee3.id,
  status: "accepted"
})

# Meeting outcome for event 4
{:ok, _} = Repo.insert(%MeetingOutcome{
  event_id: event4.id,
  summary: "Good demo with Michael and 2 team members (Sales Manager and Marketing Lead). Team was engaged and asked thoughtful questions about AI automation features and Slack integration. Main concern was pricing given their current budget constraints. Michael mentioned they're in final stages of closing Series A and want to revisit once funding is secured.",
  next_steps: [
    "Wait for Series A funding announcement",
    "Follow up within 48 hours of funding news",
    "Prepare startup-friendly proposal with flexible payment terms",
    "Share case study of similar startup success"
  ],
  sentiment_score: 65,
  key_decisions: [
    "Team likes the product and sees value",
    "Price is a concern pre-funding",
    "Will revisit after Series A closes",
    "Interest in AI automation and Slack integration"
  ],
  follow_up_required: true,
  follow_up_date: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
  meeting_rating: 4
})

# Meeting insights for event 4
{:ok, _} = Repo.insert(%MeetingInsight{
  event_id: event4.id,
  insight_type: "risk",
  title: "Budget Constraint",
  description: "Pre-funding startups have limited budgets. However, recent Series A close removes this constraint. Critical to re-engage immediately.",
  confidence: 88,
  actionable: true,
  suggested_action: "Congratulate on funding and re-engage within 48 hours. Emphasize fast time-to-value for growing teams."
})

IO.puts("✓ Created event 4 with outcome and insights")

# Event 5: Future meeting with Jennifer (scheduled)
{:ok, event5} = Calendar.create_event(user.id, %{
  title: "Global Systems - Executive Alignment Call",
  contact_id: contact3.id,
  deal_id: deal3.id,
  description: "Call to understand POC timeline and address any concerns",
  start_time: DateTime.utc_now() |> DateTime.add(5, :day) |> DateTime.truncate(:second),
  end_time: DateTime.utc_now() |> DateTime.add(5, :day) |> DateTime.add(1800, :second) |> DateTime.truncate(:second),
  type: "call",
  status: "scheduled",
  priority: "medium"
})

# Add attendees to event 5
{:ok, _} = Repo.insert(%EventAttendee{
  event_id: event5.id,
  attendee_id: attendee4.id,
  status: "pending"
})

# Meeting preparation for event 5
{:ok, _} = Repo.insert(%MeetingPreparation{
  event_id: event5.id,
  suggested_talking_points: [
    "Understand status of datacenter migration project",
    "Clarify POC timeline and any other blockers",
    "Assess competitive situation",
    "Identify if we need executive sponsor engagement",
    "Discuss alternative approaches if POC timeline is too long"
  ],
  recent_interactions: [
    "No contact in 3 weeks since POC discussion",
    "Jennifer mentioned datacenter migration taking priority",
    "Security review went well with CISO",
    "Committee was cautiously interested in initial presentation"
  ],
  deal_context: "Deal value: $250,000. Stage: Proposal. Probability: 40%. Expected close in 90 days.",
  competitor_intel: [
    "Evaluating 3 vendors (including us)",
    "POC request suggests they're not fully convinced",
    "May favor competitor with existing enterprise relationships"
  ],
  personal_notes: [
    "Jennifer is evaluator, not champion",
    "Need to engage CEO or President for strategic partnership",
    "Large enterprise - long sales cycle expected"
  ],
  documents_to_share: [
    "Enterprise customer references",
    "Security & compliance documentation",
    "Expedited POC proposal (if appropriate)"
  ]
})

IO.puts("✓ Created event 5 with preparation notes")

# ============================================================================
# ACTION ITEMS (Dashboard Feed)
# ============================================================================
IO.puts("\n🎯 Creating action items...")

{:ok, _} = Repo.insert(%ActionItem{
  user_id: user.id,
  icon: "📧",
  title: "Respond to Sarah's data residency question",
  item_type: "urgent",
  dismissed: false
})

{:ok, _} = Repo.insert(%ActionItem{
  user_id: user.id,
  icon: "📞",
  title: "Follow up with Michael Chen about Series A",
  item_type: "follow_up",
  dismissed: false
})

{:ok, _} = Repo.insert(%ActionItem{
  user_id: user.id,
  icon: "⚠️",
  title: "Deal stalling: Global Systems Corp needs attention",
  item_type: "risk",
  dismissed: false
})

{:ok, _} = Repo.insert(%ActionItem{
  user_id: user.id,
  icon: "📄",
  title: "Prepare implementation materials for TechCorp",
  item_type: "task",
  dismissed: false
})

{:ok, _} = Repo.insert(%ActionItem{
  user_id: user.id,
  icon: "📅",
  title: "Contract Review meeting in 2 days with Sarah",
  item_type: "upcoming_meeting",
  dismissed: false
})

{:ok, _} = Repo.insert(%ActionItem{
  user_id: user.id,
  icon: "💡",
  title: "Upsell opportunity: TechCorp expansion to 3 departments",
  item_type: "opportunity",
  dismissed: false
})

{:ok, _} = Repo.insert(%ActionItem{
  user_id: user.id,
  icon: "✅",
  title: "Send startup case study to Michael",
  item_type: "task",
  dismissed: false
})

{:ok, _} = Repo.insert(%ActionItem{
  user_id: user.id,
  icon: "🎉",
  title: "TechCorp deal 90% likely to close this week",
  item_type: "forecast",
  dismissed: false
})

IO.puts("✓ Created 8 action items")

# ============================================================================
# SUMMARY
# ============================================================================
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("✅ SEED DATA CREATED SUCCESSFULLY!")
IO.puts(String.duplicate("=", 70))
IO.puts("\n👤 USER CREDENTIALS:")
IO.puts("   Email: noob@flow.com")
IO.puts("   Password: password123")
IO.puts("   Name: noob")
IO.puts("   Role: sales")

IO.puts("\n📊 SUMMARY:")
IO.puts("   • 3 Contacts with full communication history")
IO.puts("   • 3 Deals with activities, insights, and signals")
IO.puts("   • 3 Conversations with 16 messages (+ analysis)")
IO.puts("   • 5 Calendar events (2 upcoming, 3 past)")
IO.puts("   • 8 Action items for dashboard feed")
IO.puts("   • 6 Tags applied across entities")

IO.puts("\n📇 CONTACTS:")
IO.puts("\n   1. Sarah Johnson - TechCorp Industries")
IO.puts("      Status: High engagement, closing this week")
IO.puts("      Health: 88/100 | Churn Risk: 12%")
IO.puts("      Deal: $85,000 | Probability: 90%")
IO.puts("      Tags: Hot Lead, Enterprise, Contract Review")
IO.puts("      • 5 communication events")
IO.puts("      • 3 AI insights")
IO.puts("      • 7 messages in active conversation")
IO.puts("      • 3 calendar events")

IO.puts("\n   2. Michael Chen - InnovateStart")
IO.puts("      Status: Re-engagement opportunity (Series A funded)")
IO.puts("      Health: 62/100 | Churn Risk: 38%")
IO.puts("      Deal: $18,000 | Probability: 65%")
IO.puts("      Tags: Startup, Urgent")
IO.puts("      • 5 communication events")
IO.puts("      • 3 AI insights")
IO.puts("      • 7 messages (active conversation)")
IO.puts("      • 2 calendar events")

IO.puts("\n   3. Jennifer Martinez - Global Systems Corp")
IO.puts("      Status: Large enterprise, deal stalling")
IO.puts("      Health: 45/100 | Churn Risk: 55%")
IO.puts("      Deal: $250,000 | Probability: 40%")
IO.puts("      Tags: Enterprise")
IO.puts("      • 4 communication events")
IO.puts("      • 2 AI insights")
IO.puts("      • 2 messages (no recent activity)")
IO.puts("      • 1 calendar event")

IO.puts("\n💰 FORECASTING DATA:")
IO.puts("   Total Pipeline: $353,000")
IO.puts("   Weighted Pipeline: $194,700")
IO.puts("   • High confidence: $85,000 (90% - closing this week)")
IO.puts("   • Medium confidence: $18,000 (65% - 3 weeks)")
IO.puts("   • Medium confidence: $250,000 (40% - 90 days)")

IO.puts("\n📈 DEAL INSIGHTS & SIGNALS:")
IO.puts("   • 6 deal insights (opportunities, risks, strategies)")
IO.puts("   • 7 deal signals (engagement, budget, timeline, competitive)")
IO.puts("   • 8 deal activities tracked")

IO.puts("\n💬 MESSAGE HISTORY:")
IO.puts("   • 16 messages across 3 conversations")
IO.puts("   • 7 messages in Sarah's conversation (contract negotiation)")
IO.puts("   • 7 messages in Michael's conversation (post-funding)")
IO.puts("   • 2 messages in Jennifer's conversation (stalled)")
IO.puts("   • Full message analysis (topics, sentiment, intent)")
IO.puts("   • Action items and suggested responses")

IO.puts("\n📅 CALENDAR:")
IO.puts("   • 2 upcoming meetings/calls")
IO.puts("   • 3 completed events with outcomes")
IO.puts("   • Meeting preparations with talking points")
IO.puts("   • Meeting insights and next steps")

IO.puts("\n🎯 ACTION FEED:")
IO.puts("   • 8 actionable items for dashboard")
IO.puts("   • Urgent follow-ups, risks, opportunities")
IO.puts("   • Meeting reminders and tasks")

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("🚀 Ready to test your CRM!\n")
