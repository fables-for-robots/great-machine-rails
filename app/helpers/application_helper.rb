module ApplicationHelper
  # Seconds as a person says them: 42s, 3m 07s, 2h 14m.
  def lasted(seconds)
    seconds = seconds.to_i
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      format("%dm %02ds", seconds / 60, seconds % 60)
    else
      format("%dh %02dm", seconds / 3600, seconds % 3600 / 60)
    end
  end
end
