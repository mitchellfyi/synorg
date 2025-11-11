# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent, ".find_by_cached" do
  let(:agent) { create(:agent, key: "test-agent", name: "Test Agent") }
  let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }

  around do |example|
    # Temporarily use MemoryStore for caching tests
    original_cache = Rails.cache
    Rails.cache = cache_store
    cache_store.clear

    example.run

    Rails.cache = original_cache
  end

  it "caches agent lookups" do
    # Clear cache first to ensure fresh lookup
    Rails.cache.delete("agent:test-agent")

    # Verify agent exists
    expect(agent).to be_persisted
    expect(described_class.find_by(key: "test-agent")).to eq(agent)

    # First call should hit database and cache the result
    result1 = described_class.find_by_cached("test-agent")
    expect(result1).to eq(agent)
    expect(Rails.cache.exist?("agent:test-agent")).to be true

    # Second call should use cache (verify no additional database query)
    query_count = 0
    allow(described_class).to receive(:find_by) do |*args|
      query_count += 1
      described_class.unscoped.find_by(*args)
    end

    result2 = described_class.find_by_cached("test-agent")
    expect(result2).to eq(agent)
    expect(query_count).to eq(0), "Expected cache hit, but database was queried"
  end

  it "returns nil for non-existent agents" do
    result = described_class.find_by_cached("non-existent")
    expect(result).to be_nil
  end

  it "invalidates cache on update" do
    # Cache the agent
    described_class.find_by_cached("test-agent")
    expect(Rails.cache.exist?("agent:test-agent")).to be true

    # Update should clear cache
    agent.update!(name: "Updated Name")
    expect(Rails.cache.exist?("agent:test-agent")).to be false
  end

  it "invalidates cache on destroy" do
    # Cache the agent
    described_class.find_by_cached("test-agent")
    expect(Rails.cache.exist?("agent:test-agent")).to be true

    # Destroy should clear cache
    agent.destroy!
    expect(Rails.cache.exist?("agent:test-agent")).to be false
  end

  it "expires cache after 1 hour" do
    # Clear cache first
    Rails.cache.delete("agent:test-agent")

    # Cache the agent
    described_class.find_by_cached("test-agent")
    expect(Rails.cache.exist?("agent:test-agent")).to be true

    # Travel forward in time beyond expiration
    travel 2.hours do
      # Cache should be expired, so should hit database again
      expect(described_class).to receive(:find_by).with(key: "test-agent").and_call_original
      described_class.find_by_cached("test-agent")
    end
  end
end
