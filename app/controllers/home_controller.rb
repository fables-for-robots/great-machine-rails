# The one page of the demo: which pod answered, and which release it runs.
class HomeController < ApplicationController
  before_action { Release::REQUESTS.increment }

  def index
    @facts = facts
    @watch = params[:watch].present?
  end

  def info
    render json: facts
  end

  private

  def facts
    {
      greeting: ENV.fetch("GREETING", "Hello from great-machine"),
      pod: Socket.gethostname,
      release: Release::NAME,
      revision: Release::REVISION,
      hue: Release::HUE,
      started_at: Release::STARTED_AT.iso8601,
      up_for: (Time.now.utc - Release::STARTED_AT).round,
      requests: Release::REQUESTS.value,
      pid: Process.pid,
      rails: Rails.version,
      ruby: RUBY_VERSION,
      environment: Rails.env
    }
  end
end
