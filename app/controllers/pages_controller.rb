class PagesController < ApplicationController
  def root
    render plain: <<~TEXT
      Cinder — short-lived log uploads for Omarchy.

      Usage:
        curl -F "file=@log.txt" -F "expires=24" #{request.base_url}

      Logs expire automatically. Text only. Be kind.
    TEXT
  end
end
