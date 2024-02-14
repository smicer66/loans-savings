defmodule LoanSavingsSystem.Repo.Migrations.CreateTblOnPlatformNotifications do
  use Ecto.Migration

  def change do
    create table(:tbl_on_platform_notifications) do
      add :message, :string
      add :sentByUserId, :integer
      add :sentByUserRoleId, :integer
      add :recipientUserID, :integer
      add :recipientUserRoleId, :integer
      add :readYes, :boolean, default: false, null: false

      timestamps()
    end

  end
end
