defmodule AriaWeb.SessionController do
  use AriaWeb, :controller

  alias Aria.Accounts
  alias AriaWeb.MultiProvider
  alias AriaWeb.Plugs.UserAuth

  def login(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      UserAuth.log_in_user(conn, user, user_params)
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> redirect(to: "/login")
    end
  end

  def logout(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  def oauth(conn, %{"provider" => provider}) do
    {:ok, %{url: url, session_params: _session_params}} =
      provider
      |> String.to_atom()
      |> MultiProvider.request()

    conn
    |> redirect(external: url)
  end

  def callback(conn, %{"provider" => provider, "state" => state} = params) do
    session_params = %{state: state}

    {:ok, %{user: user, token: token}} =
      provider
      |> String.to_atom()
      |> MultiProvider.callback(params, session_params)
      |> IO.inspect()

    {:ok, user} = Accounts.register_oauth_user(provider, user, token)
    UserAuth.log_in_user(conn, user)
  end
end
