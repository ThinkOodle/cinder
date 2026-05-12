class ApplicationController < ActionController::Base
  # Cloudflare sets CF-Connecting-IP to the real client IP. The origin must be
  # reachable only via Cloudflare (firewall or Tunnel) for this to be trustworthy.
  def client_ip
    request.headers["CF-Connecting-IP"].presence || request.remote_ip
  end
end
