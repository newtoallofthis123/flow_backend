defmodule FlowApi.Search.DataSerializerTest do
  use FlowApi.DataCase, async: true

  alias FlowApi.Search.DataSerializer
  alias FlowApi.Deals.Deal
  alias FlowApi.Contacts.Contact
  alias FlowApi.Calendar.Event

  describe "serialize_deal/1" do
    test "serializes deal with all fields" do
      deal = %Deal{
        id: "deal-123",
        title: "Acme Corp Deal",
        company: "Acme Corp",
        value: Decimal.new("50000"),
        stage: "proposal",
        probability: 75,
        confidence: "high",
        priority: "high",
        expected_close_date: ~D[2025-12-31],
        description: "Large enterprise deal",
        tags: [%{name: "enterprise"}, %{name: "priority"}],
        inserted_at: DateTime.utc_now()
      }

      result = DataSerializer.serialize_deal(deal)

      assert result.id == "deal-123"
      assert result.title == "Acme Corp Deal"
      assert result.value == "$50000"
      assert result.stage == "proposal"
      assert result.tags == ["enterprise", "priority"]
    end

    test "handles nil values gracefully" do
      deal = %Deal{
        id: "deal-456",
        title: "Test Deal",
        company: nil,
        value: nil,
        stage: "prospect",
        inserted_at: DateTime.utc_now()
      }

      result = DataSerializer.serialize_deal(deal)

      assert result.company == ""
      assert result.value == "$0"
    end
  end

  describe "serialize_contact/1" do
    test "serializes contact with all fields" do
      contact = %Contact{
        id: "contact-123",
        name: "John Doe",
        email: "john@example.com",
        company: "Test Inc",
        health_score: 85,
        sentiment: "positive",
        tags: [%{name: "vip"}]
      }

      result = DataSerializer.serialize_contact(contact)

      assert result.name == "John Doe"
      assert result.health_score == 85
      assert result.tags == ["vip"]
    end
  end

  describe "serialize_event/1" do
    test "serializes event with all fields" do
      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, 3600, :second)

      event = %Event{
        id: "event-123",
        title: "Demo Call",
        description: "Product demo for prospect",
        start_time: start_time,
        end_time: end_time,
        type: "demo",
        status: "scheduled",
        priority: "high",
        tags: [%{name: "important"}]
      }

      result = DataSerializer.serialize_event(event)

      assert result.title == "Demo Call"
      assert result.type == "demo"
      assert result.tags == ["important"]
    end
  end
end
