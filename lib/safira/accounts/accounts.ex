defmodule Safira.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Safira.Repo

  alias Safira.Accounts.User
  alias Safira.Accounts.Attendee
  alias Safira.Accounts.Manager
  alias Safira.Accounts.Company

  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_preload!(id) do
    Repo.get!(User, id)
    |> Repo.preload(:attendee)
    |> Repo.preload(:company)
    |> Repo.preload(:manager)
  end

  def get_user_email(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_preload_email!(email) do
    Repo.get_by!(User, email: email)
    |> Repo.preload(:attendee)
    |> Repo.preload(:company)
    |> Repo.preload(:manager)
  end

  def get_user_preload_email(email) do
    Repo.get_by(User, email: email)
    |> Repo.preload(:attendee)
    |> Repo.preload(:company)
    |> Repo.preload(:manager)
  end

  def get_user_token(token) do
    Repo.get_by(User, reset_password_token: token)
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  def list_attendees do
    Repo.all(Attendee)
  end

  def list_active_attendees do
    Repo.all(from a in Attendee, where: not is_nil(a.user_id))
    |> Repo.preload(:badges)
    |> Repo.preload(:prizes)
    |> Enum.map(fn x -> Map.put(x, :badge_count, length(Enum.filter(x.badges,fn x -> x.type != 0 end))) end)
  end

  def list_active_volunteers_attendees do
    Repo.all(from a in Attendee,
      where: not is_nil(a.user_id),
      where: a.volunteer == ^true
    )
    |> Repo.preload(:badges)
  end

  def get_attendee!(id) do
    Repo.get!(Attendee, id)
    |> Repo.preload(:badges)
    |> Repo.preload(:user)
    |> Repo.preload(:prizes)
  end

  def get_attendee_with_badge_count!(id) do
    get_attendee(id)
    |> (fn x -> Map.put(x, :badge_count,
     length(Enum.filter(x.badges,fn x -> x.type != 0 end))) end).()
  end

  def get_attendee(id) do
    Repo.get(Attendee, id)
    |> Repo.preload(:badges)
    |> Repo.preload(:user)
    |> Repo.preload(:prizes)
  end

  def get_attendee_by_discord_association_code(discord_association_code) do
    case Ecto.UUID.cast(discord_association_code) do
      {:ok, casted_code} -> Repo.get_by(Attendee, discord_association_code: casted_code)
      _ -> nil
    end
  end

  def get_attendee_by_discord_id(discord_id) do
      Repo.get_by(Attendee, discord_id: discord_id)
  end

  def create_attendee(attrs \\ %{}) do
    %Attendee{}
    |> Attendee.changeset(attrs)
    |> Repo.insert()
  end

  def update_attendee(%Attendee{} = attendee, attrs) do
    attendee
    |> Attendee.update_changeset(attrs)
    |> Repo.update()
  end

  def update_attendee_association(%Attendee{} = attendee, attrs) do
    attendee
    |> Attendee.update_changeset_discord_association(attrs)
    |> Repo.update()
  end

  def update_attendee_sign_up(%Attendee{} = attendee, attrs) do
    attendee
    |> Attendee.update_changeset_sign_up(attrs)
    |> Repo.update()
  end

  def volunteer_update_attendee(%Attendee{} = attendee, attrs) do
    attendee
    |> Attendee.volunteer_changeset(attrs)
    |> Repo.update()
  end


  def delete_attendee(%Attendee{} = attendee) do
    Repo.delete(attendee)
  end

  def change_attendee(%Attendee{} = attendee) do
    Attendee.changeset(attendee, %{})
  end

  def is_volunteer(%Attendee{} = attendee) do
    attendee.volunteer
  end

  def list_managers do
    Repo.all(Manager)
  end

  def get_manager!(id), do: Repo.get!(Manager, id)

  def get_manager_by_email(email) do
    Repo.all(
      from m in Manager,
        join: u in assoc(m, :user),
        where: u.email == ^email,
        preload: [user: u]
    )
  end

  def create_manager(attrs \\ %{}) do
    %Manager{}
    |> Manager.changeset(attrs)
    |> Repo.insert()
  end

  def update_manager(%Manager{} = manager, attrs) do
    manager
    |> Manager.changeset(attrs)
    |> Repo.update()
  end

  def delete_manager(%Manager{} = manager) do
    Repo.delete(manager)
  end

  def change_manager(%Manager{} = manager) do
    Manager.changeset(manager, %{})
  end

  def list_companies do
    Repo.all(Company)
  end

  def get_company!(id), do: Repo.get!(Company, id)

  def create_company(attrs \\ %{}) do
    %Company{}
    |> Company.changeset(attrs)
    |> Repo.insert()
  end


  def delete_company(%Company{} = company) do
    Repo.delete(company)
  end

  def change_company(%Company{} = company) do
    Company.changeset(company, %{})
  end

  def is_company(conn) do
    get_user(conn)
    |> Map.fetch!(:company)
    |> is_nil
    |> Kernel.not()
  end

  def is_manager(conn) do
    get_user(conn)
    |> Map.fetch!(:manager)
    |> is_nil
    |> Kernel.not()
  end

  def get_user(conn) do
    with %User{} = user <- Guardian.Plug.current_resource(conn) do
      user
      |> Map.fetch!(:id)
      |> get_user_preload!()
    end
  end
end
