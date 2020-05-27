# Remit with Elixir LiveView

A lab by Henrik ca 2020-05-15.

Focused on experimenting with LiveView so not very polished.

## Plan

- [ ] Get comments via webhook, cause clients to update
  - [ ] Make separate copies of comments for each person who gets to see it
  - [ ] Include reactions on comments in feed, not just comments proper
- [ ] Polish commits view
- [ ] Comments view
- [ ] Proper link to oldest commit
- [ ] Show an indicator when you've been reviewing for a long time
- [ ] Indicate when a commit is being viewed by someone (Except by its author?)
- [ ] Decide whether we want usecs in datetimes or not

Last:
- [ ] Consider case sensitivity with username matching
- [ ] Handle missed messages on reconnection (https://curiosum.dev/blog/elixir-phoenix-liveview-messenger-part-4?)
- [ ] Tests
- [ ] Error reporting (Honeybadger)
- [ ] CI setup
- [ ] Devbox setup
- [ ] Docs (e.g. Fluid.app)
- [ ] Consider open sourcing
- [ ] Bump Heroku plan if needed
- [ ] Recurring job to remove old data

Done:
- [x] "Oldest commit" and similar stats at top
- [x] Settings tab
- [x] Basics
- [x] Add Tailwind
- [x] Store when Settings are read; expire old ones
- [x] Consider making it a single LiveView with multiple subcomponents, so switching between tabs is snappier
- [x] Styling
- [x] Polish settings tab
- [x] Highlight commits you're currently reviewing
- [x] Settings: nilify blanks
- [x] Gravatars
- [x] Store settings in session? https://github.com/martinsvalin/spyfall/pull/1/files
- [x] Maybe skip NProgress? Makes stuff feel slower than it is.
- [x] Lock down prod access
- [x] Get commits via webhook, cause clients to update

## Dev

Assumed to be run *outside* of devbox, at the time of writing.

First time:

    # Creates DB, migrates, seeds
    mix ecto.setup

Every time:

    mix phx.server

Then visit <http://localhost:4000?auth_key=dev>

You can run this to fake new commits coming in via webhook:

    mix wh.commits

## Production

The `POOL_SIZE` for the running dyno is 18, so we've got 2 spare on a Heroku hobby plan.

Deploy:

    script/deploy

Console:

    script/prodc

Need to reset the DB on Heroku because you've rethought everything about the DB? Carefully:

    heroku pg:info  # Get DB name, e.g. dancing-nimbly-12345
    heroku pg:reset dancing-nimbly-12345
    heroku run "POOL_SIZE=2 mix ecto.migrate"

### Setup

Configure ENV variables for `AUTH_KEY` and `WEBHOOK_KEY`.

Add a webhook on each reviewed repo in GitHub (at Auctionet, we've got scripts to do this in batch).

The hook should be something like:

    Payload URL: https://my-remit.herokuapp.com/webhooks/github?auth_key=your_WEBHOOK_KEY_value
    Content type: application/json
    Secret: (left empty – it's part of the URL instead)
    Select events:
    - Commit comments
    - Pushes

You should see a happy green checkmark on GitHub, and if you click the hook, "Recent Deliveries" should show a successful ping-pong interaction.

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
