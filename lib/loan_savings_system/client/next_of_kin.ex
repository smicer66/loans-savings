defmodule LoanSavingsSystem.Client.NextOfKin do
  @derive {Jason.Encoder, only: [:firstName, :lastName, :otherName, :addressLine1, :addressLine2, :city, :districtId, :districtName, :provinceId, :provinceName, :accountId, :userId, :clientId]}
  use Ecto.Schema
  import Ecto.Changeset

  schema "tbl_next_of_kin" do
    field :accountId, :integer
    field :addressLine1, :string
    field :addressLine2, :string
    field :city, :string
    field :clientId, :integer
    field :districtId, :integer
    field :districtName, :string
    field :firstName, :string
    field :lastName, :string
    field :otherName, :string
    field :provinceId, :integer
    field :provinceName, :string
    field :userId, :integer

    timestamps()
  end

  @doc false
  def changeset(next_of_kin, attrs) do
    next_of_kin
    |> cast(attrs, [:firstName, :lastName, :otherName, :addressLine1, :addressLine2, :city, :districtId, :districtName, :provinceId, :provinceName, :accountId, :userId, :clientId])
    |> validate_required([:firstName, :lastName, :otherName, :addressLine1, :addressLine2, :city, :districtId, :districtName, :provinceId, :provinceName, :accountId, :userId, :clientId])
  end
end
