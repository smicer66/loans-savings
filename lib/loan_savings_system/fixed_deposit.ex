defmodule LoanSavingsSystem.FixedDeposit do
  @moduledoc """
  The FixedDeposit context.
  """

  import Ecto.Query, warn: false
  alias LoanSavingsSystem.Repo

  alias LoanSavingsSystem.FixedDeposit.FixedDeposits
  alias LoanSavingsSystem.Client.UserBioData

  @doc """
  Returns the list of tbl_fixed_deposit.

  ## Examples

      iex> list_tbl_fixed_deposit()
      [%FixedDeposits{}, ...]

  """
  def list_tbl_fixed_deposit do
    Repo.all(FixedDeposits)
  end

  def list_transactions do
    FixedDeposits
    |> join(:left, [a], u in "tbl_account", on: a.userId == u.userId)
    |> join(:left, [a], uB in "tbl_user_bio_data", on: a.userId == uB.userId)
    |> join(:left, [a], p in "tbl_products", on: a.productId == p.id)
    |> select([a, u, uB, p], %{
      accountNo: u.accountNo,
      principalAmount: a.principalAmount,
      fixedPeriod: a.fixedPeriod,
      fixedPeriodType: a.fixedPeriodType,
      interestRate: a.interestRate,
      interestRateType: a.interestRateType,
      accruedInterest: a.accruedInterest,
      currency: a.currency,
      currencyDecimals: a.currencyDecimals,
      yearLengthInDays: a.yearLengthInDays,
      totalDepositCharge: a.totalDepositCharge,
      totalWithdrawalCharge: a.totalWithdrawalCharge,
      totalPenalties: a.totalPenalties,
      totalAmountPaidOut: a.totalAmountPaidOut,
      startDate: a.startDate,
      endDate: a.endDate,
      isMatured: a.isMatured,
      isDivested: a.isDivested,
      isWithdrawn: a.isWithdrawn,
      expectedInterest: a.expectedInterest,
      firstName: uB.firstName,
      lastName: uB.lastName,
      productName: p.name,
      fixedDepositStatus: a.fixedDepositStatus,
      id: a.id
    })
    |> Repo.all()
  end

  @doc """
  Gets a single fixed_deposits.

  Raises `Ecto.NoResultsError` if the Fixed deposits does not exist.

  ## Examples

      iex> get_fixed_deposits!(123)
      %FixedDeposits{}

      iex> get_fixed_deposits!(456)
      ** (Ecto.NoResultsError)

  """
  def get_fixed_deposits!(id), do: Repo.get!(FixedDeposits, id)



  def range(params) do
    IO.inspect "---------------------------------------------------------------------"
IO.inspect params
    fixedPeriodType = get_in(params, ["fixedPeriodType"])
    principal_minimum = get_in(params, ["principal_minimum"])
    principal_maximum = get_in(params, ["principal_maximum"])
    intrest_min = get_in(params, ["intrest_min"])
    intrest_max = get_in(params, ["intrest_max"])
    tenure_min = get_in(params, ["tenure_min"])
    tenure_max = get_in(params, ["tenure_max"])
    start_date = start_date_conversion(params)
    end_date = end_date_conversion(params)
    params = %{
      principal_minimum: principal_minimum,
      principal_maximum: principal_maximum,
      intrest_min: intrest_min,
      intrest_max: intrest_max,
      tenure_min: tenure_min,
      tenure_max: tenure_max,
      start_date: start_date,
      end_date: end_date,
      fixedPeriodType: fixedPeriodType
    }

    Divestment
    |> search(params)
    |> Repo.all()
  end

  def search(_Divestment, params) do

   %{columns: _, num_rows: _, rows: [[principal_minimum_result]]} =  Ecto.Adapters.SQL.query!(Repo, "select min(u.principalAmount) from tbl_fixed_deposit u", [])
   %{columns: _, num_rows: _, rows: [[principal_maximum_result]]} = Ecto.Adapters.SQL.query!(Repo, "select max(u.principalAmount) from tbl_fixed_deposit u", [])
   %{columns: _, num_rows: _, rows: [[intrest_min_result]]} = Ecto.Adapters.SQL.query!(Repo, "select min(u.interestRate) from tbl_fixed_deposit u", [])
   %{columns: _, num_rows: _, rows: [[intrest_max_result]]} = Ecto.Adapters.SQL.query!(Repo, "select max(u.interestRate) from tbl_fixed_deposit u", [])
   %{columns: _, num_rows: _, rows: [[tenure_min_result]]} = Ecto.Adapters.SQL.query!(Repo, "select min(u.fixedPeriod) from tbl_fixed_deposit u", [])
   %{columns: _, num_rows: _, rows: [[tenure_max_result]]} = Ecto.Adapters.SQL.query!(Repo, "select max(u.fixedPeriod) from tbl_fixed_deposit u", [])
   %{columns: _, num_rows: _, rows: [[start_date_min]]} = Ecto.Adapters.SQL.query!(Repo, "SELECT min(u.inserted_at) FROM tbl_fixed_deposit u", [])
   %{columns: _, num_rows: _, rows: [[end_date_max]]} = Ecto.Adapters.SQL.query!(Repo, "SELECT max(u.inserted_at) FROM tbl_fixed_deposit u", [])


   principal_minimum = if params.principal_minimum == "", do: principal_minimum_result, else: params.principal_minimum
   principal_maximum = if params.principal_maximum == "", do: principal_maximum_result, else: params.principal_maximum

   intrest_min = if params.intrest_min == "", do: intrest_min_result, else: params.intrest_min
   intrest_max = if params.intrest_max == "", do: intrest_max_result, else: params.intrest_max

   tenure_min = if params.tenure_min == "", do: tenure_min_result, else: params.tenure_min
   tenure_max = if params.tenure_max == "", do: tenure_max_result, else: params.tenure_max


    start_date = if params.start_date == "", do: start_date_min, else: params.start_date
    end_date = if params.end_date == "", do: end_date_max, else: params.end_date

    from d in FixedDeposits,
    or_where: d.principalAmount >= ^principal_minimum and d.principalAmount <= ^principal_maximum and
             d.interestRate >= ^intrest_min and d.interestRate <= ^intrest_max and
             d.fixedPeriod >= ^tenure_min and d.fixedPeriod <= ^tenure_max and
             d.inserted_at >= ^start_date and d.inserted_at <= ^end_date,
      select:
      struct(
        d,
        [
          :principalAmount,
          :fixedPeriod,
          :fixedPeriodType,
          :interestRate,
          :interestRateType,
          :expectedInterest,
          :accruedInterest,
          :currency,
          :currencyDecimals,
          :yearLengthInDays,
          :totalDepositCharge,
          :totalWithdrawalCharge,
          :totalPenalties,
          :totalAmountPaidOut,
          :startDate,
          :endDate
        ]
      )


  end

  def start_date_conversion(params) do

   %{columns: _, num_rows: _, rows: [[start_date_min]]} = Ecto.Adapters.SQL.query!(Repo, "SELECT min(u.inserted_at) FROM tbl_fixed_deposit u", [])
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

  @doc """
  Creates a fixed_deposits.

  ## Examples

      iex> create_fixed_deposits(%{field: value})
      {:ok, %FixedDeposits{}}

      iex> create_fixed_deposits(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_fixed_deposits(attrs \\ %{}) do
    %FixedDeposits{}
    |> FixedDeposits.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a fixed_deposits.

  ## Examples

      iex> update_fixed_deposits(fixed_deposits, %{field: new_value})
      {:ok, %FixedDeposits{}}

      iex> update_fixed_deposits(fixed_deposits, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_fixed_deposits(%FixedDeposits{} = fixed_deposits, attrs) do
    fixed_deposits
    |> FixedDeposits.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a fixed_deposits.

  ## Examples

      iex> delete_fixed_deposits(fixed_deposits)
      {:ok, %FixedDeposits{}}

      iex> delete_fixed_deposits(fixed_deposits)
      {:error, %Ecto.Changeset{}}

  """
  def delete_fixed_deposits(%FixedDeposits{} = fixed_deposits) do
    Repo.delete(fixed_deposits)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking fixed_deposits changes.

  ## Examples

      iex> change_fixed_deposits(fixed_deposits)
      %Ecto.Changeset{source: %FixedDeposits{}}

  """
  def change_fixed_deposits(%FixedDeposits{} = fixed_deposits) do
    FixedDeposits.changeset(fixed_deposits, %{})
  end

  alias LoanSavingsSystem.FixedDeposit.FixedDepositTransaction

  @doc """
  Returns the list of tbl_fixed_deposit_transactions.

  ## Examples

      iex> list_tbl_fixed_deposit_transactions()
      [%FixedDepositTransaction{}, ...]

  """
  def list_tbl_fixed_deposit_transactions do
    Repo.all(FixedDepositTransaction)
  end



  @doc """
  Gets a single fixed_deposit_transaction.

  Raises `Ecto.NoResultsError` if the Fixed deposit transaction does not exist.

  ## Examples

      iex> get_fixed_deposit_transaction!(123)
      %FixedDepositTransaction{}

      iex> get_fixed_deposit_transaction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_fixed_deposit_transaction!(id), do: Repo.get!(FixedDepositTransaction, id)

  @doc """
  Creates a fixed_deposit_transaction.

  ## Examples

      iex> create_fixed_deposit_transaction(%{field: value})
      {:ok, %FixedDepositTransaction{}}

      iex> create_fixed_deposit_transaction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_fixed_deposit_transaction(attrs \\ %{}) do
    %FixedDepositTransaction{}
    |> FixedDepositTransaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a fixed_deposit_transaction.

  ## Examples

      iex> update_fixed_deposit_transaction(fixed_deposit_transaction, %{field: new_value})
      {:ok, %FixedDepositTransaction{}}

      iex> update_fixed_deposit_transaction(fixed_deposit_transaction, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_fixed_deposit_transaction(%FixedDepositTransaction{} = fixed_deposit_transaction, attrs) do
    fixed_deposit_transaction
    |> FixedDepositTransaction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a fixed_deposit_transaction.

  ## Examples

      iex> delete_fixed_deposit_transaction(fixed_deposit_transaction)
      {:ok, %FixedDepositTransaction{}}

      iex> delete_fixed_deposit_transaction(fixed_deposit_transaction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_fixed_deposit_transaction(%FixedDepositTransaction{} = fixed_deposit_transaction) do
    Repo.delete(fixed_deposit_transaction)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking fixed_deposit_transaction changes.

  ## Examples

      iex> change_fixed_deposit_transaction(fixed_deposit_transaction)
      %Ecto.Changeset{source: %FixedDepositTransaction{}}

  """
  def change_fixed_deposit_transaction(%FixedDepositTransaction{} = fixed_deposit_transaction) do
    FixedDepositTransaction.changeset(fixed_deposit_transaction, %{})
  end
end
