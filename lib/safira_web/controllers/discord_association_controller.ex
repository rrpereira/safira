defmodule SafiraWeb.DiscordAssociationController do
  use SafiraWeb, :controller

  alias Safira.Accounts

  action_fallback SafiraWeb.FallbackController

  def show(conn, %{"id" => discord_id}) do
    cond do
      Accounts.is_company(conn) || Accounts.is_manager(conn) ->
        show_aux(conn, discord_id)

      true ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Cannot access resource"})
        |> halt()
    end
  end

  # association_params= %{"discord_association_code" => discord_association_code, "discord_id" => discord_id}
  def create(conn, association_params) do
    cond do
      Accounts.is_manager(conn) ->
        association_aux(conn, association_params)

      true ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Cannot access resource"})
        |> halt()
    end
  end

  defp show_aux(conn, discord_id) do
    attendee = Accounts.get_attendee_by_discord_id(discord_id)

    cond do
      not is_nil(attendee) ->
        conn
        |> put_status(:ok)
        |> json(%{id: attendee.id})

      true ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No attendee with that discord_id"})
    end
  end

  defp association_aux(
         conn,
         association_params = %{
           "discord_association_code" => discord_association_code,
           "discord_id" => _discord_id
         }
       ) do
    company_code = Application.fetch_env!(:safira, :company_code)
    staff_code = Application.fetch_env!(:safira, :staff_code)
    speaker_code = Application.fetch_env!(:safira, :speaker_code)

    case discord_association_code do
      ^company_code -> notify_succesful_association(conn, "empresa")
      ^staff_code -> notify_succesful_association(conn, "staff")
      ^speaker_code -> notify_succesful_association(conn, "orador")
      _ -> associate_attendee(conn, association_params)
    end
  end

  defp associate_attendee(conn, %{
         "discord_association_code" => discord_association_code,
         "discord_id" => discord_id
       }) do
    attendee = Accounts.get_attendee_by_discord_association_code(discord_association_code)

    cond do
      not is_nil(attendee) ->
        # no need for checking if discord_id is valid
        # since the the user's discord_id is obtained by the bot through the discord API
        Accounts.update_attendee_association(attendee, %{discord_id: discord_id})
        notify_succesful_association(conn, "participante")

      true ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Unable to associate"})
    end
  end

  defp notify_succesful_association(conn, role) do
    conn
    |> put_status(:created)
    |> json(%{association: role})
  end
end
