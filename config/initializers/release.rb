# What this process is, for the page to say.
#
# great-machine starts the application out of the Nix store, and every build
# of it is another store path: that path is the release. Run out of a
# checkout there is none, and the directory stands in for it.
module Release
  ROOT = Rails.root.realpath.to_s
  STORE_PATH = ROOT[%r{\A/nix/store/[^/]+}]
  NAME = STORE_PATH ? File.basename(STORE_PATH) : ROOT

  # The commit the release was built from, which the Nix build writes down.
  REVISION = begin
    Rails.root.join("REVISION").read.strip
  rescue SystemCallError
    nil
  end

  # A colour of its own for every release, so that two of them are told
  # apart at a glance while a rollout moves the pods from one to the other.
  HUE = Digest::SHA256.hexdigest(NAME)[0, 8].to_i(16) % 360

  STARTED_AT = Time.now.utc
  REQUESTS = Concurrent::AtomicFixnum.new
end
