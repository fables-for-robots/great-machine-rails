# great-machine-rails

A Rails application to roll out with
[great-machine](https://github.com/fables-for-robots/great-machine): one
page that says which pod answered and which release it runs.

It is a demo of the rollout, not of Rails. Every build of it is another
release, with a colour of its own, so that while a rollout moves the pods
from one release to the next, reloading the page shows them change over.

- `/` the page; with `?watch=1` it asks again every second
- `/info` the same as JSON
- `/up` Rails' own health check

Rails 8.1 on Ruby 3.4, generated with `rails new --minimal`, with no
database and no asset pipeline.

## How great-machine runs it

`great-machine rollout` is given one file in the Nix store. It pushes the
closure of the store path that file is in, and every pod of the service
starts the file. Here the file is `bin/great-machine-rails` of the flake's
default package:

```sh
nix build
./result/bin/great-machine-rails        # Puma, http://localhost:8080/
```

Its closure is Ruby, the gems, the application and a shell, about 150 MiB.
The file starts Puma in the `production` environment on port 8080. What the
application needs beyond that it takes from the environment, which for a
pod is that of its app container:

| Variable | Meaning | Without it |
|---|---|---|
| `PORT` | the port Puma listens on | 8080 |
| `GREETING` | the heading of the page | `Hello from great-machine` |
| `SECRET_KEY_BASE` | what Rails signs with; a real application gives every pod the same one | a new one at every start |
| `RAILS_LOG_LEVEL` | how much is logged | `info` |
| `RAILS_ENV` | the environment | `production` |

Three things make a Rails application fit to be started this way, and this
one has them:

- **It writes nothing beside itself.** It runs out of the Nix store, which
  cannot be written to: the log goes to standard output (`great-machine
  logs` shows it), the cache is in memory, and no pid file is written.
- **It needs nothing of the image.** The image of the app container has a
  shell and little else: no `/usr/share/zoneinfo`, so the time zones come
  from the gem `tzinfo-data`; no locale, so the file that starts it says
  `C.UTF-8`.
- **Its secrets are not in the build.** There is no `config/master.key` and
  no credentials file: what is built is pushed to a store, and a secret
  belongs in the environment of the container.

## Deploy

What has to be there:

- **A Linux machine of the pods' architecture to build on.** A pod runs
  Linux, and the build of a Mac is one for macOS.
- **`great-machine` on that machine's `PATH`**, and Nix:

  ```sh
  nix profile install github:fables-for-robots/great-machine/v0.1.0 \
    --option allow-unsafe-native-code-during-evaluation true
  ```

- **The machine's operator ID on draal's list.** `great-machine id` prints
  it; draal is given it in `GREAT_MACHINE_OPERATORS`.
- **A service to roll out to**: pods whose app container runs
  `great-machine zathras` for the service, here called `demo`, and send
  port 8080 to whoever asks.

Then:

```sh
export GREAT_MACHINE_DRAAL=<the endpoint ID of draal>

nix build
great-machine rollout demo ./result/bin/great-machine-rails
```

The command pushes what the store does not have yet (everything the first
time, the application alone after a change of it), has every pod fetch it,
moves the pods to it one at a time, and ends when all of them run it. To
watch it:

```sh
great-machine tui                # the fleet, live; s opens a shell in a pod
great-machine status demo
great-machine logs -f demo       # the log of Rails, of every pod
```

**To see a rollout happen**, open the page with `?watch=1`, change
something (the heading in `app/views/home/index.html.erb`, say), commit it,
and build and roll out again: the colour and the release change pod by pod.
Rolling out the same build again restarts the pods one at a time.

```sh
great-machine rollback demo      # after a rollout that halted: back to the last one that completed
```

### With direnv

The dev shell has the built application on its `PATH`, and direnv builds it
anew when the application changes (`direnv allow` once). On the Linux
machine a deploy is then one line, of what the tree holds:

```sh
great-machine rollout demo "$(command -v great-machine-rails)"
```

### From a Mac

Build on the Linux machine, copy the closure over, and roll out from the
Mac, whose operator ID draal then has to know:

```sh
out=$(ssh LINUX 'cd great-machine-rails && git pull -q && nix build --no-link --print-out-paths')
nix copy --no-check-sigs --from ssh://LINUX "$out"
great-machine rollout demo "$out/bin/great-machine-rails"
```

`nix copy --no-check-sigs` is for a trusted user of Nix on the Mac.

## Develop

```sh
nix develop                      # or direnv
bin/rails server                 # development, http://localhost:3000/
bin/rails console
```

`nix run` starts the production build, as a pod does, on port 8080.

Nix sees only the files that git tracks: `git add` a new file before it is
built.

### After a change of the Gemfile

The gems are built by Nix from `gemset.nix`, which
[bundix](https://github.com/nix-community/bundix) writes from
`Gemfile.lock`. Both are written anew so:

```sh
nix shell nixpkgs#ruby_3_4 nixpkgs#bundler nixpkgs#bundix --command \
  sh -c 'BUNDLE_FORCE_RUBY_PLATFORM=1 bundle lock && bundix'
```

`BUNDLE_FORCE_RUBY_PLATFORM` keeps the lock file to gems that are built
from source, which is what Nix builds for whatever platform it is asked.

## What a real application adds

- **A database** is reached over the network, by a URL in the environment
  of the app container. A pod has no disk of its own that outlives it.
- **Assets** are compiled in the Nix build (`rails assets:precompile` in
  the derivation of the application), since nothing can be written where
  the application runs.
- **Migrations** are a step of their own before the rollout.
- **`SECRET_KEY_BASE`**, and every other secret, from a Secret of the
  cluster in the environment of the app container.
