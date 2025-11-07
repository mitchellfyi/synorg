# frozen_string_literal: true

require "rails_helper"

RSpec.describe DevToolingAgentService do
  describe "#run" do
    let(:service) { described_class.new }

    it "returns a success response" do
      result = service.run
      expect(result[:success]).to be true
    end

    it "generates recommendations" do
      result = service.run
      expect(result[:recommendations]).to be_an(Array)
    end

    it "includes recommendation count" do
      result = service.run
      expect(result[:recommendations_count]).to eq(result[:recommendations].length)
    end

    context "when Playwright is missing" do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?)
          .with(Rails.root.join("playwright.config.ts"))
          .and_return(false)
      end

      it "recommends adding Playwright" do
        result = service.run
        playwright_rec = result[:recommendations].find { |r| r[:title].include?("Playwright") }
        expect(playwright_rec).to be_present
        expect(playwright_rec[:category]).to eq("testing")
      end
    end

    context "when SimpleCov is missing" do
      before do
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read)
          .with(Rails.root.join("Gemfile"))
          .and_return("gem 'rails'\ngem 'rspec'")
      end

      it "recommends adding SimpleCov" do
        result = service.run
        simplecov_rec = result[:recommendations].find { |r| r[:title].include?("SimpleCov") }
        expect(simplecov_rec).to be_present
        expect(simplecov_rec[:category]).to eq("testing")
      end
    end

    context "when RuboCop lacks GitHub preset" do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?)
          .with(Rails.root.join(".rubocop.yml"))
          .and_return(true)
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read)
          .with(Rails.root.join(".rubocop.yml"))
          .and_return("AllCops:\n  TargetRubyVersion: 3.2")
      end

      it "recommends upgrading RuboCop configuration" do
        result = service.run
        rubocop_rec = result[:recommendations].find { |r| r[:title].include?("RuboCop") }
        expect(rubocop_rec).to be_present
        expect(rubocop_rec[:category]).to eq("linting")
      end
    end

    it "categorizes recommendations by priority" do
      result = service.run
      result[:recommendations].each do |rec|
        expect(rec[:priority]).to be_in(%w[low medium high])
      end
    end

    it "categorizes recommendations by category" do
      result = service.run
      result[:recommendations].each do |rec|
        expect(rec[:category]).to be_present
      end
    end

    context "when an error occurs" do
      before do
        allow(service).to receive(:audit_repository).and_raise(StandardError, "Test error")
      end

      it "returns an error response" do
        result = service.run
        expect(result[:success]).to be false
        expect(result[:error]).to eq("Test error")
      end
    end
  end
end
