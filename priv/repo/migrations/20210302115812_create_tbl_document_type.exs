defmodule LoanSavingsSystem.Repo.Migrations.CreateTblDocumentType do
  use Ecto.Migration

  def change do
    create table(:tbl_document_type) do
      add :name, :string
      add :createdByUserId, :integer
      add :deleted_at, :date
      add :description, :string
      add :documentFormats, :string

      timestamps()
    end

  end
end
