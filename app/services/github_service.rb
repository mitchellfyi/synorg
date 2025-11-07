# frozen_string_literal: true

require "net/http"
require "json"

# Service to wrap GitHub API calls
# Provides methods for interacting with issues, pulls, and comments
class GithubService
  GITHUB_API_BASE = "https://api.github.com"

  attr_reader :repo_full_name, :token

  def initialize(repo_full_name, token)
    @repo_full_name = repo_full_name
    @token = token
  end

  # Get an issue
  #
  # @param issue_number [Integer] Issue number
  # @return [Hash, nil] Issue data or nil
  def get_issue(issue_number)
    get_request("/repos/#{repo_full_name}/issues/#{issue_number}")
  end

  # List issues
  #
  # @param state [String] Issue state (open, closed, all)
  # @param labels [String] Comma-separated list of labels
  # @return [Array<Hash>] Array of issues
  def list_issues(state: "open", labels: nil)
    params = { state: state }
    params[:labels] = labels if labels

    get_request("/repos/#{repo_full_name}/issues", params)
  end

  # Create an issue comment
  #
  # @param issue_number [Integer] Issue number
  # @param body [String] Comment body
  # @return [Hash, nil] Comment data or nil
  def create_issue_comment(issue_number, body)
    post_request(
      "/repos/#{repo_full_name}/issues/#{issue_number}/comments",
      { body: body }
    )
  end

  # Get a pull request
  #
  # @param pr_number [Integer] PR number
  # @return [Hash, nil] PR data or nil
  def get_pull_request(pr_number)
    get_request("/repos/#{repo_full_name}/pulls/#{pr_number}")
  end

  # Create a pull request
  #
  # @param title [String] PR title
  # @param body [String] PR body
  # @param head [String] Head branch
  # @param base [String] Base branch
  # @return [Hash, nil] PR data or nil
  def create_pull_request(title:, body:, head:, base:)
    post_request(
      "/repos/#{repo_full_name}/pulls",
      {
        title: title,
        body: body,
        head: head,
        base: base
      }
    )
  end

  # List pull request files
  #
  # @param pr_number [Integer] PR number
  # @return [Array<Hash>] Array of files
  def list_pull_request_files(pr_number)
    get_request("/repos/#{repo_full_name}/pulls/#{pr_number}/files")
  end

  private

  def get_request(path, params = {})
    uri = URI("#{GITHUB_API_BASE}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    execute_request(uri, request)
  end

  def post_request(path, body)
    uri = URI("#{GITHUB_API_BASE}#{path}")
    request = Net::HTTP::Post.new(uri)
    request.body = body.to_json
    execute_request(uri, request)
  end

  def execute_request(uri, request)
    request["Authorization"] = "token #{token}"
    request["Accept"] = "application/vnd.github.v3+json"
    request["Content-Type"] = "application/json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error("GitHub API error: #{response.code} - #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("GitHub API request failed: #{e.message}")
    nil
  end
end
