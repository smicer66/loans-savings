defmodule LoanSavingsSystemWeb.FcubeGeneralLedgerController do
  use LoanSavingsSystemWeb, :controller

  alias LoanSavingsSystem.Repo
  alias LoanSavingsSystem.Products
  alias LoanSavingsSystem.Logs.UserLogs
  alias LoanSavingsSystem.Divestments
  alias LoanSavingsSystem.Divestments.DivestmentPackage
  alias LoanSavingsSystem.Products.Product
  alias LoanSavingsSystem.SystemSetting
  alias LoanSavingsSystem.Charges
  alias LoanSavingsSystem.Charges.Charge
  alias LoanSavingsSystem.Products.ProductCharge
  alias LoanSavingsSystem.Accounts.UserRole
  alias LoanSavingsSystem.Accounts.User
  alias LoanSavingsSystem.Client.UserBioData
  alias LoanSavingsSystem.EndOfDay
  alias LoanSavingsSystem.EndOfDay.FcubeGeneralLedger
  require Record
  require Logger
  import Ecto.Query, warn: false

  require Logger

  plug(
    LoanSavingsSystemWeb.Plugs.EnforcePasswordPolicy
      when action not in [:new_password, :change_password]
    )

  def index(conn, _params) do
    fcube_general_ledger = EndOfDay.list_fcube_general_ledger()
    render(conn, "index.html", fcube_general_ledger: fcube_general_ledger)
  end

  def new(conn, _params) do
    changeset = EndOfDay.change_fcube_general_ledger(%FcubeGeneralLedger{})
    render(conn, "new.html", changeset: changeset)
  end

  def edit(conn, _params) do
    changeset = EndOfDay.change_fcube_general_ledger(%FcubeGeneralLedger{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, params) do


	for x <- 0..(Enum.count(params["account_name"])-1) do
		Logger.info ">>>>>>>>>>>>"
		fcubeGeneralLedger =
		%{
			account_name: Enum.at(params["account_name"], x),
			gl_account_no: Enum.at(params["gl_account_no"], x)
		}
		FcubeGeneralLedger.changeset(%FcubeGeneralLedger{}, fcubeGeneralLedger)
		|> Repo.insert()

	end


	conn
	|> put_flash(:info, "Flexcube General Ledger Accounts created/updated successfully.")
	|> redirect(to: "/Savings/Update-Flexcube")
  end

  def show(conn, %{"id" => id}) do
    fcube_general_ledger = EndOfDay.get_fcube_general_ledger!(id)
    render(conn, "show.html", fcube_general_ledger: fcube_general_ledger)
  end

  def edit(conn, %{"id" => id}) do
    fcube_general_ledger = EndOfDay.get_fcube_general_ledger!(id)
    changeset = EndOfDay.change_fcube_general_ledger(fcube_general_ledger)
    render(conn, "edit.html", fcube_general_ledger: fcube_general_ledger, changeset: changeset)
  end

  def update(conn, %{"id" => id, "fcube_general_ledger" => fcube_general_ledger_params}) do
    fcube_general_ledger = EndOfDay.get_fcube_general_ledger!(id)

    case EndOfDay.update_fcube_general_ledger(fcube_general_ledger, fcube_general_ledger_params) do
      {:ok, fcube_general_ledger} ->
        conn
        |> put_flash(:info, "Fcube general ledger updated successfully.")
        |> redirect(to: Routes.fcube_general_ledger_path(conn, :show, fcube_general_ledger))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", fcube_general_ledger: fcube_general_ledger, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    fcube_general_ledger = EndOfDay.get_fcube_general_ledger!(id)
    {:ok, _fcube_general_ledger} = EndOfDay.delete_fcube_general_ledger(fcube_general_ledger)

    conn
    |> put_flash(:info, "Fcube general ledger deleted successfully.")
    |> redirect(to: Routes.fcube_general_ledger_path(conn, :index))
  end
end
