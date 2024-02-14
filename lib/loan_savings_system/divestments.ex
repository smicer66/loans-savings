defmodule LoanSavingsSystem.Divestments do
  @moduledoc """
  The Divestments context.
  """

  import Ecto.Query, warn: false
  alias LoanSavingsSystem.Repo

  alias LoanSavingsSystem.Divestments.DivestmentPackage

  @doc """
  Returns the list of tbl_divestment_package.

  ## Examples

      iex> list_tbl_divestment_package()
      [%DivestmentPackage{}, ...]

  """
  def list_tbl_divestment_package do
    #Repo.all(DivestmentPackage)
    #|>join()
    DivestmentPackage
      |> join(:left, [p], c in "tbl_products", on: p.productId == c.id)
      |> select([p, c], %{
        id: p.id,
        startPeriodDays: p.startPeriodDays,
        endPeriodDays: p.endPeriodDays,
        divestmentValuation: p.divestmentValuation,
        productId: p.productId,
        status: p.status,
        clientId: p.clientId,
        productName: c.name
      })
      |> Repo.all()
  end

  @doc """
  Gets a single divestment_package.

  Raises `Ecto.NoResultsError` if the Divestment package does not exist.

  ## Examples

      iex> get_divestment_package!(123)
      %DivestmentPackage{}

      iex> get_divestment_package!(456)
      ** (Ecto.NoResultsError)

  """
  def get_divestment_package!(id), do: Repo.get!(DivestmentPackage, id)

  @doc """
  Creates a divestment_package.

  ## Examples

      iex> create_divestment_package(%{field: value})
      {:ok, %DivestmentPackage{}}

      iex> create_divestment_package(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_divestment_package(attrs \\ %{}) do
    %DivestmentPackage{}
    |> DivestmentPackage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a divestment_package.

  ## Examples

      iex> update_divestment_package(divestment_package, %{field: new_value})
      {:ok, %DivestmentPackage{}}

      iex> update_divestment_package(divestment_package, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_divestment_package(%DivestmentPackage{} = divestment_package, attrs) do
    divestment_package
    |> DivestmentPackage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a divestment_package.

  ## Examples

      iex> delete_divestment_package(divestment_package)
      {:ok, %DivestmentPackage{}}

      iex> delete_divestment_package(divestment_package)
      {:error, %Ecto.Changeset{}}

  """
  def delete_divestment_package(%DivestmentPackage{} = divestment_package) do
    Repo.delete(divestment_package)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking divestment_package changes.

  ## Examples

      iex> change_divestment_package(divestment_package)
      %Ecto.Changeset{source: %DivestmentPackage{}}

  """
  def change_divestment_package(%DivestmentPackage{} = divestment_package) do
    DivestmentPackage.changeset(divestment_package, %{})
  end

  alias LoanSavingsSystem.Divestments.Divestment

  @doc """
  Returns the list of tbl_divestments.

  ## Examples

      iex> list_tbl_divestments()
      [%Divestment{}, ...]

  """
  def list_tbl_divestments do
    Repo.all(Divestment)
  end

  def principal_range_amount(params) do

    max = get_in(params, ["max"])
    min = get_in(params, ["min"])
    min_devest = get_in(params, ["min_devest"])
    max_devest = get_in(params, ["max_devest"])
    min_interest = get_in(params, ["min_interest"])
    max_interest = get_in(params, ["max_interest"])
    start_date = start_date_conversion(params)
    end_date = end_date_conversion(params)
    params = %{min: min, max: max, min_devest: min_devest, max_devest: max_devest, min_interest: min_interest, max_interest: max_interest, start_date: start_date, end_date: end_date}

    Divestment
    |> search(params)
    |> Repo.all()
  end

  def search(_Divestment, params) do

   %{columns: _, num_rows: _, rows: [[result]]} =  Ecto.Adapters.SQL.query!(Repo, "select min(u.principalAmount) from tbl_divestments u", [])
   %{columns: _, num_rows: _, rows: [[result_max]]} = Ecto.Adapters.SQL.query!(Repo, "select max(u.principalAmount) from tbl_divestments u", [])
   %{columns: _, num_rows: _, rows: [[devestment_amt_min]]} = Ecto.Adapters.SQL.query!(Repo, "select min(u.divestAmount) from tbl_divestments u", [])
   %{columns: _, num_rows: _, rows: [[devestment_amt_max]]} = Ecto.Adapters.SQL.query!(Repo, "select max(u.divestAmount) from tbl_divestments u", [])
   %{columns: _, num_rows: _, rows: [[interest_rate_min]]} = Ecto.Adapters.SQL.query!(Repo, "select min(u.interestRate) from tbl_divestments u", [])
   %{columns: _, num_rows: _, rows: [[interest_rate_max]]} = Ecto.Adapters.SQL.query!(Repo, "select max(u.interestRate) from tbl_divestments u", [])



   %{columns: _, num_rows: _, rows: [[start_date_min]]} = Ecto.Adapters.SQL.query!(Repo, "SELECT min(u.inserted_at) FROM tbl_divestments u", [])
   %{columns: _, num_rows: _, rows: [[end_date_max]]} = Ecto.Adapters.SQL.query!(Repo, "SELECT max(u.inserted_at) FROM tbl_divestments u", [])


    min = if params.min == "", do: result, else: params.min
    max = if params.max == "", do: result_max, else: params.max

    min_devest = if params.min_devest == "", do: devestment_amt_min, else: params.min_devest
    max_devest = if params.max_devest == "", do: devestment_amt_max, else: params.max_devest

    min_interest = if params.min_interest == "", do: interest_rate_min, else: params.min_interest
    max_interest = if params.max_interest == "", do: interest_rate_max, else: params.max_interest


    start_date = if params.start_date == "", do: start_date_min, else: params.start_date
    end_date = if params.end_date == "", do: end_date_max, else: params.end_date

    from d in Divestment,
    or_where: d.principalAmount >= ^min and d.principalAmount <= ^max and
             d.divestAmount >= ^min_devest and d.divestAmount <= ^max_devest and
             d.interestRate >= ^min_interest and d.interestRate <= ^max_interest and
             d.inserted_at >= ^start_date and d.inserted_at <= ^end_date,
      select:
      struct(
        d,
        [
          :principalAmount,
          :divestAmount,
          :interestRate,
          :divestmentDate,
          :updated_at,
          :inserted_at
        ]
      )


  end

  def start_date_conversion(params) do

   %{columns: _, num_rows: _, rows: [[start_date_min]]} = Ecto.Adapters.SQL.query!(Repo, "SELECT min(u.inserted_at) FROM tbl_divestments u", [])
    case params["start_date"] == "" do
        true -> start_date_min
        false ->

        date =  NaiveDateTime.new Date.from_iso8601!(params["start_date"]), ~T[00:00:00]
        {:ok , changed_date} = date
        start_date1 = Timex.beginning_of_day(changed_date)
        start_date2 = to_string(start_date1)
        start_date = String.slice(start_date2, 0..15)

        IO.inspect start_date, label: "Start date"

      end
  end

  def end_date_conversion(params) do

    case params["end_date"] == "" do
      true -> Timex.now()
      false ->
      date =  NaiveDateTime.new Date.from_iso8601!(params["end_date"]), ~T[00:00:00]
      {:ok , changed_date2} = date
      end_date1 = Timex.end_of_day(changed_date2)
      end_date2 = to_string(end_date1)
      end_date = String.slice(end_date2, 0..15)

      IO.inspect end_date, label: "End date"
    end

   end

  #  def last_date_of_the_month do

  #   datetime = DateTime.utc_now()
  #   date = DateTime.to_date(datetime)
  #   last_day_of_previous_month = Date.add(date, date.day * -1) |> NaiveDateTime.new!(~T[23:59:59])
  #  end

  # con = NaiveDateTime.to_string(start_date_min)
  # contrim = String.trim("#{start_date_min}", "~N[]")
  # # con = String.trim_trailing("#{contrim}")
  # con = contrim |> String.slice(0..9)
  # con = NaiveDateTime.new Date.from_iso8601!(con)
  # String.replace(start_date_min, "~N[", "")


  # def principal_range_amount(params) do
  #   Divestment
  #   |> search(params)
  #   |> Repo.all()
  # end

  # def search(query, params) do
  #   query
  #   |> handle_date_filter(params)
  # end


  # defp handle_date_filter(query, %{"start_date" => start_date, "end_date" => end_date})
  #      when start_date == "" or is_nil(start_date) or end_date == "" or is_nil(end_date),
  #      do: query

  # defp handle_date_filter(query, %{"start_date" => start_date, "end_date" => end_date}) do
  #   query
  #   |> where(
  #     [a],
  #     fragment("CAST(? AS DATE) >= ?", a.inserted_at, ^start_date) and
  #     fragment("CAST(? AS DATE) <= ?", a.inserted_at, ^end_date)
  #   )
  # end

  # # defp handle_filename_filter(query, %{"min_devest" => min_devest})
  # #      when min_devest == "" or is_nil(min_devest),
  # #      do: query

  # # defp handle_filename_filter(query, %{"min_devest" => min_devest}) do
  # #   where(query, [a], fragment("lower(?) LIKE lower(?)", a.principalAmount, ^"%#{min_devest}%"))
  # # end



  # # working function max and min amount in the sql query

  # # def principal_range_amount(params) do
  # #   IO.inspect params

  # #   max = get_in(params, ["max"])
  # #   min = get_in(params, ["min"])
  # #   params = %{min: min, max: max}

  # #   Divestment
  # #   |> search(params)
  # #   |> Repo.all()
  # # end

  # # def search(_Divestment, params) do

  # #   min = if params.min == "", do: 100, else: params.min
  # #   max = if params.max == "", do: 600, else: params.max
  # #   # max(principalAmount)

  # #   from d in Divestment,
  # #     where: d.principalAmount >= ^min and d.principalAmount <= ^max,
  # #     select:
  # #     struct(
  # #       d,
  # #       [
  # #         :principalAmount
  # #       ]
  # #     )

  #   # %{columns: _, num_rows: _, rows: [[result]]} =  Ecto.Adapters.SQL.query!(Repo, "select min(u.principalAmount) from tbl_divestments u", [])
  # # end

  @doc """
  Gets a single divestment.

  Raises `Ecto.NoResultsError` if the Divestment does not exist.

  ## Examples

      iex> get_divestment!(123)
      %Divestment{}

      iex> get_divestment!(456)
      ** (Ecto.NoResultsError)

  """


  def get_divestment!(id), do: Repo.get!(Divestment, id)

  @doc """
  Creates a divestment.

  ## Examples

      iex> create_divestment(%{field: value})
      {:ok, %Divestment{}}

      iex> create_divestment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_divestment(attrs \\ %{}) do
    %Divestment{}
    |> Divestment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a divestment.

  ## Examples

      iex> update_divestment(divestment, %{field: new_value})
      {:ok, %Divestment{}}

      iex> update_divestment(divestment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_divestment(%Divestment{} = divestment, attrs) do
    divestment
    |> Divestment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a divestment.

  ## Examples

      iex> delete_divestment(divestment)
      {:ok, %Divestment{}}

      iex> delete_divestment(divestment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_divestment(%Divestment{} = divestment) do
    Repo.delete(divestment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking divestment changes.

  ## Examples

      iex> change_divestment(divestment)
      %Ecto.Changeset{source: %Divestment{}}

  """
  def change_divestment(%Divestment{} = divestment) do
    Divestment.changeset(divestment, %{})
  end

  alias LoanSavingsSystem.Divestments.DivestmentTransaction

  @doc """
  Returns the list of tbl_divestment_transactions.

  ## Examples

      iex> list_tbl_divestment_transactions()
      [%DivestmentTransaction{}, ...]

  """
  def list_tbl_divestment_transactions do
    Repo.all(DivestmentTransaction)
  end

  @doc """
  Gets a single divestment_transaction.

  Raises `Ecto.NoResultsError` if the Divestment transaction does not exist.

  ## Examples

      iex> get_divestment_transaction!(123)
      %DivestmentTransaction{}

      iex> get_divestment_transaction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_divestment_transaction!(id), do: Repo.get!(DivestmentTransaction, id)

  @doc """
  Creates a divestment_transaction.

  ## Examples

      iex> create_divestment_transaction(%{field: value})
      {:ok, %DivestmentTransaction{}}

      iex> create_divestment_transaction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_divestment_transaction(attrs \\ %{}) do
    %DivestmentTransaction{}
    |> DivestmentTransaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a divestment_transaction.

  ## Examples

      iex> update_divestment_transaction(divestment_transaction, %{field: new_value})
      {:ok, %DivestmentTransaction{}}

      iex> update_divestment_transaction(divestment_transaction, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_divestment_transaction(%DivestmentTransaction{} = divestment_transaction, attrs) do
    divestment_transaction
    |> DivestmentTransaction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a divestment_transaction.

  ## Examples

      iex> delete_divestment_transaction(divestment_transaction)
      {:ok, %DivestmentTransaction{}}

      iex> delete_divestment_transaction(divestment_transaction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_divestment_transaction(%DivestmentTransaction{} = divestment_transaction) do
    Repo.delete(divestment_transaction)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking divestment_transaction changes.

  ## Examples

      iex> change_divestment_transaction(divestment_transaction)
      %Ecto.Changeset{source: %DivestmentTransaction{}}

  """
  def change_divestment_transaction(%DivestmentTransaction{} = divestment_transaction) do
    DivestmentTransaction.changeset(divestment_transaction, %{})
  end

end
