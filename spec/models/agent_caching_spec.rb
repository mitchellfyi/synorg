# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent, "caching" do
  describe ".find_by_cached" do
    let(:agent) { create(:agent, key: "test-agent", name: "Test Agent") }

    before do
      # Clear cache before each test
      Rails.cache.clear
    end

    it "caches agent lookups" do
      # First call should hit database
      expect(Agent).to receive(:find_by).with(key: "test-agent").and_call_original
      result1 = Agent.find_by_cached("test-agent")
      expect(result1).to eq(agent)

      # Second call should use cache
      expect(Agent).not_to receive(:find_by)
      result2 = Agent.find_by_cached("test-agent")
      expect(result2).to eq(agent)
    end

    it "returns nil for non-existent agents" do
      result = Agent.find_by_cached("non-existent")
      expect(result).to be_nil
    end

    it "invalidates cache on update" do
      # Cache the agent
      Agent.find_by_cached("test-agent")

      # Update should clear cache
      expect(Rails.cache).to receive(:delete).with("agent:test-agent")
      agent.update!(name: "Updated Name")
    end

    it "invalidates cache on destroy" do
      # Cache the agent
      Agent.find_by_cached("test-agent")

      # Destroy should clear cache
      expect(Rails.cache).to receive(:delete).with("agent:test-agent")
      agent.destroy
    end

    it "expires cache after 1 hour" do
      # Cache the agent
      Agent.find_by_cached("test-agent")

      # Travel forward in time
      travel 2.hours do
        # Should hit database again after expiration
        expect(Agent).to receive(:find_by).with(key: "test-agent").and_call_original
        Agent.find_by_cached("test-agent")
      end
    end
  end
end
