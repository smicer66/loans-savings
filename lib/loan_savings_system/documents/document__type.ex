defmodule LoanSavingsSystem.Documents.Document_Type do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tbl_document_type" do
    field :createdByUserId, :integer
    field :deleted_at, :date
    field :description, :string
    field :documentFormats, :string
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(document__type, attrs) do
    document__type
    |> cast(attrs, [:name, :createdByUserId, :deleted_at, :description, :documentFormats])
    |> validate_required([:name, :createdByUserId, :deleted_at, :description, :documentFormats])
  end
end
