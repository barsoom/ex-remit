# Remit

## Dev

Assumed to be run *outside* of devbox, at the time of writing.

First time:

    # Creates DB, migrates, seeds
    mix ecto.setup

Every time:

    mix phx.server

Then visit <http://localhost:4000>

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
