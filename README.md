# Remit with Elixir LiveView

A lab by Henrik ca 2020-05-15.

Focused on experimenting with LiveView so not very polished.


## Dev

Assumed to be run *outside* of devbox, at the time of writing.

First time:

    # Creates DB, migrates, seeds
    mix ecto.setup

Every time:

    mix phx.server

Then visit <http://localhost:4000>

## Production

Migrate:

    # The POOL_SIZE for the running dyno is 18, so we've got 2 spare on a Heroku hobby plan.
    heroku run "POOL_SIZE=2 mix ecto.migrate"

## Example queries

Because we don't work with Ecto often and may forget.

    # TODO: Make this automatically happen in a console
    import Ecto.Query
    alias Remit.{Repo,Commit}

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
