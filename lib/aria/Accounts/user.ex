defmodule Aria.Accounts.User do
  @moduledoc """
  Schema representing accounts_users.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__
  alias Aria.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "accounts_users" do
    field :name, :string
    field :email, :string
    field :is_confirmed, :boolean, default: false
    field :password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime

    timestamps()
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email()
    |> validate_password(opts)
  end

  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, %{confirmed_at: now, is_confirmed: true})
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> maybe_password_confirmation(opts)
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[^\w\s])/,
      message:
        "password must includes at least one upper case character, one lower case character, one digit and one special character"
    )
    |> maybe_hash_password(opts)
  end

  defp maybe_password_confirmation(changeset, opts) do
    password_confirmation? = Keyword.get(opts, :password_confirmation, false)

    if password_confirmation? && changeset.valid? do
      changeset
      |> validate_required([:password, :password_confirmation])
      |> validate_confirmation(:password, message: "does not match password")
    else
      changeset
      |> validate_required([:password])
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
      |> delete_change(:password_confirmation)
    else
      changeset
    end
  end

  def valid_password?(%User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
