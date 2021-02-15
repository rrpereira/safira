defmodule Safira.Roulette do
  @moduledoc """
  The Roulette context.
  """

  import Ecto.Query, warn: false
  alias Safira.Repo
  alias Ecto.Multi

  alias Safira.Roulette.Prize
  alias Safira.Roulette.AttendeePrize
  alias Safira.Accounts.Attendee

  @doc """
  Returns the list of prizes.

  ## Examples

      iex> list_prizes()
      [%Prize{}, ...]

  """
  def list_prizes do
    Repo.all(Prize)
  end

  @doc """
  Gets a single prize.

  Raises `Ecto.NoResultsError` if the Prize does not exist.

  ## Examples

      iex> get_prize!(123)
      %Prize{}

      iex> get_prize!(456)
      ** (Ecto.NoResultsError)

  """
  def get_prize!(id), do: Repo.get!(Prize, id)

  @doc """
  Creates a prize.

  ## Examples

      iex> create_prize(%{field: value})
      {:ok, %Prize{}}

      iex> create_prize(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_prize(attrs \\ %{}) do
    %Prize{}
    |> Prize.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a prize.

  ## Examples

      iex> update_prize(prize, %{field: new_value})
      {:ok, %Prize{}}

      iex> update_prize(prize, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_prize(%Prize{} = prize, attrs) do
    prize
    |> Prize.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Prize.

  ## Examples

      iex> delete_prize(prize)
      {:ok, %Prize{}}

      iex> delete_prize(prize)
      {:error, %Ecto.Changeset{}}

  """
  def delete_prize(%Prize{} = prize) do
    Repo.delete(prize)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking prize changes.

  ## Examples

      iex> change_prize(prize)
      %Ecto.Changeset{source: %Prize{}}

  """
  def change_prize(%Prize{} = prize) do
    Prize.changeset(prize, %{})
  end

  @doc """
  Returns the list of attendees_prizes.

  ## Examples

      iex> list_attendees_prizes()
      [%AttendeePrize{}, ...]

  """
  def list_attendees_prizes do
    Repo.all(AttendeePrize)
  end

  @doc """
  Gets a single attendee_prize.

  Raises `Ecto.NoResultsError` if the Attendee prize does not exist.

  ## Examples

      iex> get_attendee_prize!(123)
      %AttendeePrize{}

      iex> get_attendee_prize!(456)
      ** (Ecto.NoResultsError)

  """
  def get_attendee_prize!(id), do: Repo.get!(AttendeePrize, id)

  @doc """
  Gets AttendeePrize given attendee_id and prize_id.
  """
  def get_keys_attendee_prize(attendee_id, prize_id) do
    Repo.get_by(AttendeePrize, attendee_id: attendee_id, prize_id: prize_id)
  end

  @doc """
  Creates a attendee_prize.

  ## Examples

      iex> create_attendee_prize(%{field: value})
      {:ok, %AttendeePrize{}}

      iex> create_attendee_prize(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_attendee_prize(attrs \\ %{}) do
    %AttendeePrize{}
    |> AttendeePrize.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a attendee_prize.

  ## Examples

      iex> update_attendee_prize(attendee_prize, %{field: new_value})
      {:ok, %AttendeePrize{}}

      iex> update_attendee_prize(attendee_prize, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_attendee_prize(%AttendeePrize{} = attendee_prize, attrs) do
    attendee_prize
    |> AttendeePrize.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a AttendeePrize.

  ## Examples

      iex> delete_attendee_prize(attendee_prize)
      {:ok, %AttendeePrize{}}

      iex> delete_attendee_prize(attendee_prize)
      {:error, %Ecto.Changeset{}}

  """
  def delete_attendee_prize(%AttendeePrize{} = attendee_prize) do
    Repo.delete(attendee_prize)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking attendee_prize changes.

  ## Examples

      iex> change_attendee_prize(attendee_prize)
      %Ecto.Changeset{source: %AttendeePrize{}}

  """
  def change_attendee_prize(%AttendeePrize{} = attendee_prize) do
    AttendeePrize.changeset(attendee_prize, %{})
  end

  @doc """
  Transaction that take a number of tokens from an attendee,
  apply a probability-based function for "spinning the wheel",
  and give the price to the attendee.
  """
  def spin(attendee) do
    Multi.new()
    # remove tokens from attendee to spin the wheel
    |> Multi.update(
      :attendee,
      Attendee.update_token_balance_changeset(attendee, %{
        token_balance: attendee.token_balance - Application.fetch_env!(:safira, :roulette_cost)
      })
    )
    # prize after spinning
    |> Multi.run(:prize, fn _repo, _changes -> {:ok, spin_prize()} end)
    # get an attendee_prize if exists one, or build one
    |> Multi.run(:attendee_prize, fn _repo, %{attendee: attendee, prize: prize} ->
      {:ok,
       get_keys_attendee_prize(attendee.id, prize.id) ||
         %AttendeePrize{attendee_id: attendee.id, prize_id: prize.id, quantity: 0}}
    end)
    # insert or update the existing attendee_prize
    |> Multi.insert_or_update(:upsert_atendee_prize, fn %{attendee_prize: attendee_prize} ->
      AttendeePrize.changeset(attendee_prize, %{quantity: attendee_prize.quantity + 1})
    end)
    # decrement stock of prize and possibly the probability
    |> Multi.update(:prize_stock, fn %{prize: prize} ->
      update_prize_stock(prize)
    end)
    # update probabilities if the stock of current prize is 0
    |> Multi.merge(fn %{prize_stock: prize_stock, prize: prize} ->
      update_probabilities(prize_stock, prize)
    end)
    |> serializable_transaction()
  end

  defp spin_prize() do
    random_prize = strong_randomizer() |> Float.round(3)

    prizes =
      Repo.all(Prize)
      |> Enum.filter(fn x -> x.probability > 0 end)

    cumulatives =
      prizes
      |> Enum.map_reduce(0, fn prize, acc ->
        {Float.round(acc + prize.probability, 3), acc + prize.probability}
      end)
      |> elem(0)

    prob =
      cumulatives
      |> Enum.filter(fn x -> x >= random_prize end)
      |> Enum.at(0)

    prizes
    |> Enum.at(
      cumulatives
      |> Enum.find_index(fn x -> x == prob end)
    )
  end

  defp strong_randomizer() do
    <<i1::unsigned-integer-32, i2::unsigned-integer-32, i3::unsigned-integer-32>> =
      :crypto.strong_rand_bytes(12)

    :rand.seed(:exsplus, {i1, i2, i3})
    :rand.uniform()
  end

  defp update_prize_stock(prize) do
    attrs = %{stock: prize.stock - 1}

    attrs =
      cond do
        Map.get(attrs, :stock) == 0 ->
          Map.put(attrs, :probability, 0)

        true ->
          attrs
      end

    Prize.update_changeset(prize, attrs)
  end

  defp update_probabilities(prize_stock, prize) do
    cond do
      prize_stock.stock == 0 ->
        Repo.all(Prize)
        |> Enum.filter(fn x -> x.id != prize.id end)
        |> Enum.with_index()
        |> Enum.reduce(Multi.new(), fn {x, index}, acc ->
          Multi.update(
            acc,
            index,
            Prize.update_changeset(x, %{probability: x.probability / (1 - prize.probability)})
          )
        end)

      true ->
        Multi.new()
    end
  end

  defp serializable_transaction(multi) do
    try do
      Repo.transaction(fn ->
        Repo.query!("set transaction isolation level serializable;")

        Repo.transaction(multi)
        |> case do
          {:ok, result} ->
            result

          {:error, _failed_operation, changeset, _changes_so_far} ->
            # That's the way to retrieve the changeset as a value
            Repo.rollback(changeset)
        end
      end)
    rescue
      _ ->
        # When transaction raises a serialization error means that
        # could not serialize access due to concurrent update which
        # is a correct error. After that the spinning should be repeated.
        serializable_transaction(multi)
    end
  end
end
