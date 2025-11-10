# frozen_string_literal: true

# Shared helper for agent seeding
module AgentSeeder
  def self.seed_agent(agent_attrs, prompt_content = nil)
    agent_key = agent_attrs[:key]

    agent = Agent.find_or_initialize_by(key: agent_key)
    agent.assign_attributes(
      name: agent_attrs[:name],
      description: agent_attrs[:description],
      capabilities: agent_attrs[:capabilities],
      max_concurrency: agent_attrs[:max_concurrency],
      enabled: agent_attrs[:enabled]
    )

    # Always update prompt if provided (even if agent already exists)
    agent.prompt = prompt_content if prompt_content

    agent.save!
    agent
  end
end

