defmodule LoanSavingsSystem.Loan_applicationsTest do
  use LoanSavingsSystem.DataCase

  alias LoanSavingsSystem.Loan_applications

  describe "tbl_loan_app" do
    alias LoanSavingsSystem.Loan_applications.Loan_application

    @valid_attrs %{company_id: "some company_id", customer_id: "some customer_id", customer_name: "some customer_name", loan_status: "some loan_status"}
    @update_attrs %{company_id: "some updated company_id", customer_id: "some updated customer_id", customer_name: "some updated customer_name", loan_status: "some updated loan_status"}
    @invalid_attrs %{company_id: nil, customer_id: nil, customer_name: nil, loan_status: nil}

    def loan_application_fixture(attrs \\ %{}) do
      {:ok, loan_application} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Loan_applications.create_loan_application()

      loan_application
    end

    test "list_tbl_loan_app/0 returns all tbl_loan_app" do
      loan_application = loan_application_fixture()
      assert Loan_applications.list_tbl_loan_app() == [loan_application]
    end

    test "get_loan_application!/1 returns the loan_application with given id" do
      loan_application = loan_application_fixture()
      assert Loan_applications.get_loan_application!(loan_application.id) == loan_application
    end

    test "create_loan_application/1 with valid data creates a loan_application" do
      assert {:ok, %Loan_application{} = loan_application} = Loan_applications.create_loan_application(@valid_attrs)
      assert loan_application.company_id == "some company_id"
      assert loan_application.customer_id == "some customer_id"
      assert loan_application.customer_name == "some customer_name"
      assert loan_application.loan_status == "some loan_status"
    end

    test "create_loan_application/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Loan_applications.create_loan_application(@invalid_attrs)
    end

    test "update_loan_application/2 with valid data updates the loan_application" do
      loan_application = loan_application_fixture()
      assert {:ok, %Loan_application{} = loan_application} = Loan_applications.update_loan_application(loan_application, @update_attrs)
      assert loan_application.company_id == "some updated company_id"
      assert loan_application.customer_id == "some updated customer_id"
      assert loan_application.customer_name == "some updated customer_name"
      assert loan_application.loan_status == "some updated loan_status"
    end

    test "update_loan_application/2 with invalid data returns error changeset" do
      loan_application = loan_application_fixture()
      assert {:error, %Ecto.Changeset{}} = Loan_applications.update_loan_application(loan_application, @invalid_attrs)
      assert loan_application == Loan_applications.get_loan_application!(loan_application.id)
    end

    test "delete_loan_application/1 deletes the loan_application" do
      loan_application = loan_application_fixture()
      assert {:ok, %Loan_application{}} = Loan_applications.delete_loan_application(loan_application)
      assert_raise Ecto.NoResultsError, fn -> Loan_applications.get_loan_application!(loan_application.id) end
    end

    test "change_loan_application/1 returns a loan_application changeset" do
      loan_application = loan_application_fixture()
      assert %Ecto.Changeset{} = Loan_applications.change_loan_application(loan_application)
    end
  end
end
