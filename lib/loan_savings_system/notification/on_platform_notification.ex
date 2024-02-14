defmodule LoanSavingsSystem.Notification.OnPlatformNotification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tbl_on_platform_notifications" do
    field :message, :string
    field :readYes, :boolean, default: false
    field :recipientUserID, :integer
    field :recipientUserRoleId, :integer
    field :sentByUserId, :integer
    field :sentByUserRoleId, :integer

    timestamps()
  end

  @doc false
  def changeset(on_platform_notification, attrs) do
    on_platform_notification
    |> cast(attrs, [:message, :sentByUserId, :sentByUserRoleId, :recipientUserID, :recipientUserRoleId, :readYes])
    |> validate_required([:message, :sentByUserId, :sentByUserRoleId, :recipientUserID, :recipientUserRoleId, :readYes])
  end
end
