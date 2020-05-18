# Remit with Elixir LiveView

A lab by Henrik ca 2020-05-15.

Focused on experimenting with LiveView so not very polished.

## Plan

- [x] Basics
- [x] Add Tailwind
- [ ] Styling
- [ ] Lock down prod access
- [ ] Get commits via webhook, cause clients to update
- [ ] Get comments via webhook, cause clients to update
  - [ ] Make separate copies of comments for each person who gets to see it
  - [ ] Include reactions on comments in feed, not just comments proper
- [x] Settings tab
- [ ] Polish settings tab
- [ ] Settings: nilify blanks
- [ ] Store when Settings are read; expire old ones
- [ ] Polish commits view
- [ ] Comments view
- [ ] "Oldest commit" and similar stats at top
- [ ] Handle missed messages on reconnection (https://curiosum.dev/blog/elixir-phoenix-liveview-messenger-part-4?)
- [ ] Indicate when a commit is being viewed by someone (Except by its author?)
- [ ] Tests
- [ ] Docs (e.g. Fluid.app)
- [ ] Error reporting (Honeybadger)
- [ ] Consider open sourcing

## Dev

Assumed to be run *outside* of devbox, at the time of writing.

First time:

    # Creates DB, migrates, seeds
    mix ecto.setup

Every time:

    mix phx.server

Then visit <http://localhost:4000>

## Production

The `POOL_SIZE` for the running dyno is 18, so we've got 2 spare on a Heroku hobby plan.

Migrate:

    heroku run "POOL_SIZE=2 mix ecto.migrate"

Console:

    heroku run "POOL_SIZE=2 iex -S mix"

## Example queries

Because we don't work with Ecto often and may forget.

    Repo.aggregate(Commit, :count)

    Repo.one(from c in Commit, limit: 1)

## Original instructions

To start your Phoenix server:

  * Setup the project with `mix setup`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
