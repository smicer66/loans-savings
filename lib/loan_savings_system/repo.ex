defmodule LoanSavingsSystem.Repo do
  use Ecto.Repo,
    otp_app: :loan_savings_system,

   adapter: Ecto.Adapters.Tds
end
