defmodule LoanSavingsSystem.Transactions do
  @moduledoc """
  The Transactions context.
  """

	require Record
  import Ecto.Query, warn: false
  alias LoanSavingsSystem.Repo

  alias LoanSavingsSystem.Transactions.Transaction
  alias LoanSavingsSystem.Client.UserBioData

  @doc """
  Returns the list of tbl_transactions.

  ## Examples

      iex> list_tbl_transactions()
      [%Transaction{}, ...]

  """
  def list_tbl_transactions do
    Repo.all(Transaction)
  end

  def list_transactions do
    Transaction
    |> join(:left, [a], u in "tbl_account", on: a.userId == u.userId)
    |> join(:left, [a], uB in "tbl_user_bio_data", on: a.userId == uB.userId)
    |> join(:left, [a], p in "tbl_products", on: a.productId == p.id)
    |> select([a, u, uB, p], %{
      accountNo: u.accountNo,
      totalAmount: a.totalAmount,
      productType: a.productType,
      referenceNo: a.referenceNo,
      orderRef: a.orderRef,
      transactionType: a.transactionType,
      transactionDetail: a.transactionDetail,
      transactionTypeEnum: a.transactionTypeEnum,
      status: a.status,
      inserted_at: u.inserted_at,
      firstName: uB.firstName,
      lastName: uB.lastName,
	  productName: p.name,
	  currency: a.currency,
	  newTotalBalance: a.newTotalBalance

    })
    |> Repo.all()
  end

  @doc """
  Gets a single transaction.

  Raises `Ecto.NoResultsError` if the Transaction does not exist.

  ## Examples

      iex> get_transaction!(123)
      %Transaction{}

      iex> get_transaction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_transaction!(id), do: Repo.get!(Transaction, id)

  @doc """
  Creates a transaction.

  ## Examples

      iex> create_transaction(%{field: value})
      {:ok, %Transaction{}}

      iex> create_transaction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_transaction(attrs \\ %{}) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a transaction.

  ## Examples

      iex> update_transaction(transaction, %{field: new_value})
      {:ok, %Transaction{}}

      iex> update_transaction(transaction, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a transaction.

  ## Examples

      iex> delete_transaction(transaction)
      {:ok, %Transaction{}}

      iex> delete_transaction(transaction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_transaction(%Transaction{} = transaction) do
    Repo.delete(transaction)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking transaction changes.

  ## Examples

      iex> change_transaction(transaction)
      %Ecto.Changeset{source: %Transaction{}}

  """
  def change_transaction(%Transaction{} = transaction) do
    Transaction.changeset(transaction, %{})
  end
  
  
  
	def pending_transactions() do
		status = "Pending";
		query = from au in LoanSavingsSystem.Transactions.Transaction,
			where: au.status == type(^status, :string),
			select: au
		transactions = Repo.all(query);
		transactions
	end
end
