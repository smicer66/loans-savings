defmodule LoanSavingsSystem.Documents.LoanDocument do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tbl_loan_documents" do
    field :documentLocation, :string
    field :documentName, :string
    field :loanId, :integer
    field :updatedByUserId, :integer
    field :updatedByUseroleId, :integer

    timestamps()
  end

  @doc false
  def changeset(loan_document, attrs) do
    loan_document
    |> cast(attrs, [:loanId, :documentName, :documentLocation, :updatedByUserId, :updatedByUseroleId])
    |> validate_required([:loanId, :documentName, :documentLocation, :updatedByUserId, :updatedByUseroleId])
  end
end
