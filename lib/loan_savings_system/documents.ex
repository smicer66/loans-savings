defmodule LoanSavingsSystem.Documents do
  @moduledoc """
  The Documents context.
  """

  import Ecto.Query, warn: false
  alias LoanSavingsSystem.Repo

  alias LoanSavingsSystem.Documents.Document_Type

  @doc """
  Returns the list of tbl_document_type.

  ## Examples

      iex> list_tbl_document_type()
      [%Document_Type{}, ...]

  """
  def list_tbl_document_type do
    Repo.all(Document_Type)
  end

  @doc """
  Gets a single document__type.

  Raises `Ecto.NoResultsError` if the Document  type does not exist.

  ## Examples

      iex> get_document__type!(123)
      %Document_Type{}

      iex> get_document__type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_document__type!(id), do: Repo.get!(Document_Type, id)

  @doc """
  Creates a document__type.

  ## Examples

      iex> create_document__type(%{field: value})
      {:ok, %Document_Type{}}

      iex> create_document__type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_document__type(attrs \\ %{}) do
    %Document_Type{}
    |> Document_Type.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a document__type.

  ## Examples

      iex> update_document__type(document__type, %{field: new_value})
      {:ok, %Document_Type{}}

      iex> update_document__type(document__type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_document__type(%Document_Type{} = document__type, attrs) do
    document__type
    |> Document_Type.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a document__type.

  ## Examples

      iex> delete_document__type(document__type)
      {:ok, %Document_Type{}}

      iex> delete_document__type(document__type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_document__type(%Document_Type{} = document__type) do
    Repo.delete(document__type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking document__type changes.

  ## Examples

      iex> change_document__type(document__type)
      %Ecto.Changeset{source: %Document_Type{}}

  """
  def change_document__type(%Document_Type{} = document__type) do
    Document_Type.changeset(document__type, %{})
  end

  alias LoanSavingsSystem.Documents.LoanDocumentConfirmationRequest

  @doc """
  Returns the list of tbl_loan_confirmation.

  ## Examples

      iex> list_tbl_loan_confirmation()
      [%LoanDocumentConfirmationRequest{}, ...]

  """
  def list_tbl_loan_confirmation do
    Repo.all(LoanDocumentConfirmationRequest)
  end

  @doc """
  Gets a single loan_document_confirmation_request.

  Raises `Ecto.NoResultsError` if the Loan document confirmation request does not exist.

  ## Examples

      iex> get_loan_document_confirmation_request!(123)
      %LoanDocumentConfirmationRequest{}

      iex> get_loan_document_confirmation_request!(456)
      ** (Ecto.NoResultsError)

  """
  def get_loan_document_confirmation_request!(id), do: Repo.get!(LoanDocumentConfirmationRequest, id)

  @doc """
  Creates a loan_document_confirmation_request.

  ## Examples

      iex> create_loan_document_confirmation_request(%{field: value})
      {:ok, %LoanDocumentConfirmationRequest{}}

      iex> create_loan_document_confirmation_request(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_loan_document_confirmation_request(attrs \\ %{}) do
    %LoanDocumentConfirmationRequest{}
    |> LoanDocumentConfirmationRequest.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a loan_document_confirmation_request.

  ## Examples

      iex> update_loan_document_confirmation_request(loan_document_confirmation_request, %{field: new_value})
      {:ok, %LoanDocumentConfirmationRequest{}}

      iex> update_loan_document_confirmation_request(loan_document_confirmation_request, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_loan_document_confirmation_request(%LoanDocumentConfirmationRequest{} = loan_document_confirmation_request, attrs) do
    loan_document_confirmation_request
    |> LoanDocumentConfirmationRequest.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a loan_document_confirmation_request.

  ## Examples

      iex> delete_loan_document_confirmation_request(loan_document_confirmation_request)
      {:ok, %LoanDocumentConfirmationRequest{}}

      iex> delete_loan_document_confirmation_request(loan_document_confirmation_request)
      {:error, %Ecto.Changeset{}}

  """
  def delete_loan_document_confirmation_request(%LoanDocumentConfirmationRequest{} = loan_document_confirmation_request) do
    Repo.delete(loan_document_confirmation_request)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking loan_document_confirmation_request changes.

  ## Examples

      iex> change_loan_document_confirmation_request(loan_document_confirmation_request)
      %Ecto.Changeset{source: %LoanDocumentConfirmationRequest{}}

  """
  def change_loan_document_confirmation_request(%LoanDocumentConfirmationRequest{} = loan_document_confirmation_request) do
    LoanDocumentConfirmationRequest.changeset(loan_document_confirmation_request, %{})
  end

  alias LoanSavingsSystem.Documents.LoanDocument

  @doc """
  Returns the list of tbl_loan_documents.

  ## Examples

      iex> list_tbl_loan_documents()
      [%LoanDocument{}, ...]

  """
  def list_tbl_loan_documents do
    Repo.all(LoanDocument)
  end

  @doc """
  Gets a single loan_document.

  Raises `Ecto.NoResultsError` if the Loan document does not exist.

  ## Examples

      iex> get_loan_document!(123)
      %LoanDocument{}

      iex> get_loan_document!(456)
      ** (Ecto.NoResultsError)

  """
  def get_loan_document!(id), do: Repo.get!(LoanDocument, id)

  @doc """
  Creates a loan_document.

  ## Examples

      iex> create_loan_document(%{field: value})
      {:ok, %LoanDocument{}}

      iex> create_loan_document(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_loan_document(attrs \\ %{}) do
    %LoanDocument{}
    |> LoanDocument.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a loan_document.

  ## Examples

      iex> update_loan_document(loan_document, %{field: new_value})
      {:ok, %LoanDocument{}}

      iex> update_loan_document(loan_document, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_loan_document(%LoanDocument{} = loan_document, attrs) do
    loan_document
    |> LoanDocument.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a loan_document.

  ## Examples

      iex> delete_loan_document(loan_document)
      {:ok, %LoanDocument{}}

      iex> delete_loan_document(loan_document)
      {:error, %Ecto.Changeset{}}

  """
  def delete_loan_document(%LoanDocument{} = loan_document) do
    Repo.delete(loan_document)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking loan_document changes.

  ## Examples

      iex> change_loan_document(loan_document)
      %Ecto.Changeset{source: %LoanDocument{}}

  """
  def change_loan_document(%LoanDocument{} = loan_document) do
    LoanDocument.changeset(loan_document, %{})
  end

  alias LoanSavingsSystem.Documents.OffTakerDocument

  @doc """
  Returns the list of tbl_off_taker_document_types.

  ## Examples

      iex> list_tbl_off_taker_document_types()
      [%OffTakerDocument{}, ...]

  """
  def list_tbl_off_taker_document_types do
    Repo.all(OffTakerDocument)
  end

  @doc """
  Gets a single off_taker_document.

  Raises `Ecto.NoResultsError` if the Off taker document does not exist.

  ## Examples

      iex> get_off_taker_document!(123)
      %OffTakerDocument{}

      iex> get_off_taker_document!(456)
      ** (Ecto.NoResultsError)

  """
  def get_off_taker_document!(id), do: Repo.get!(OffTakerDocument, id)

  @doc """
  Creates a off_taker_document.

  ## Examples

      iex> create_off_taker_document(%{field: value})
      {:ok, %OffTakerDocument{}}

      iex> create_off_taker_document(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_off_taker_document(attrs \\ %{}) do
    %OffTakerDocument{}
    |> OffTakerDocument.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a off_taker_document.

  ## Examples

      iex> update_off_taker_document(off_taker_document, %{field: new_value})
      {:ok, %OffTakerDocument{}}

      iex> update_off_taker_document(off_taker_document, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_off_taker_document(%OffTakerDocument{} = off_taker_document, attrs) do
    off_taker_document
    |> OffTakerDocument.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a off_taker_document.

  ## Examples

      iex> delete_off_taker_document(off_taker_document)
      {:ok, %OffTakerDocument{}}

      iex> delete_off_taker_document(off_taker_document)
      {:error, %Ecto.Changeset{}}

  """
  def delete_off_taker_document(%OffTakerDocument{} = off_taker_document) do
    Repo.delete(off_taker_document)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking off_taker_document changes.

  ## Examples

      iex> change_off_taker_document(off_taker_document)
      %Ecto.Changeset{source: %OffTakerDocument{}}

  """
  def change_off_taker_document(%OffTakerDocument{} = off_taker_document) do
    OffTakerDocument.changeset(off_taker_document, %{})
  end
end
