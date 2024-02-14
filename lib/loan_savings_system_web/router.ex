defmodule LoanSavingsSystemWeb.Router do
  use LoanSavingsSystemWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug(LoanSavingsSystemWeb.Plugs.SetUser)
    # plug(LoanSavingsSystemWeb.Plugs.SessionTimeout, timeout_after_seconds: 300)
  end



  pipeline :guest do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end


  pipeline :session do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :loans_admin_app do
    # plug(LoanSavingsSystemWeb.Plugs.RequireAdminAccess)
    plug(:put_layout, {LoanSavingsSystemWeb.LayoutView, :loans_admin_app})
  end

  pipeline :savings_admin_app do
    # plug(LoanSavingsSystemWeb.Plugs.RequireAdminAccess)
    plug(:put_layout, {LoanSavingsSystemWeb.LayoutView, :savings_admin_app})
  end

  pipeline :dashboard_layout do
    plug(:put_layout, {LoanSavingsSystemWeb.LayoutView, :dashboard_layout})
  end

  pipeline :no_layout do
    plug :put_layout, false
  end

  pipeline :employer_app do
    # plug(LoanSavingsSystemWeb.Plugs.RequireEmployerAccess)
    plug(:put_layout, {LoanSavingsSystemWeb.LayoutView, :employer_app})
  end

  pipeline :employee_app do
    # plug(LoanSavingsSystemWeb.Plugs.RequireEmployeeAccess)
    plug(:put_layout, {LoanSavingsSystemWeb.LayoutView, :employee_app})
  end

  pipeline :individual_app do
    plug(:put_layout, {LoanSavingsSystemWeb.LayoutView, :individual_app})
  end


  scope "/", LoanSavingsSystemWeb do
    pipe_through([:api, :no_layout])
    get("/emulator-ussd", UssdController, :index)
    get("/appusers", UssdController, :index)
    get("/ussd", UssdController, :initiateUssd)
    post("/mmoney/payment-confirmation", UssdController, :handlePaymentConfirmation)
    get("/api/get-loan-product-by-id", ProductController, :getLoanProductById)
    get("/api/calculate-loan-details", ProductController, :getCalculateLoanDetails)
    get("/api/user/get-user-bio-data-by-id-ajax/:bioDataId", UserController, :getUserBioDataById)
    get("/api/user/get-user-addresses-by-user-id-ajax/:userId", UserController, :getUserAddressesById)
    get("/api/user/get-user-next-of-kin-by-user-id-ajax/:userId", UserController, :getNextOfKinByUserId)
    get("/api/user/get-employer-user-by-mobile-number-and-role-type-ajax/:companyId/:mobileNumber/:roleType", UserController, :getEmployerUserByMobileNumberAndRoleType)
  end

  scope "/", LoanSavingsSystemWeb do
    pipe_through([:guest, :no_layout])

    get("/Login", SessionController, :new)
    get("/forgot-password", SessionController, :forgot_password)
    post("/forgot-password", SessionController, :post_forgot_password)
    post("/validate-otp", SessionController, :validate_otp)
    get("/new-user-set-password", SessionController, :new_user_set_password)
    post("/new_user_set_password", SessionController, :post_new_user_set_password)
    get("/loan/apply-for-a-loan", LoanController, :loan_product_guest)

    post("/Login", SessionController, :create)
  end


  scope "/", LoanSavingsSystemWeb do
    pipe_through([:session, :no_layout])
    # pipe_through :browser
    # get "/Dashboard", UserController, :dashboard
    get("/", SessionController, :username)
    post("/", SessionController, :get_username)
    get("/forgortFleetHub//password", UserController, :forgot_password)
    post("/confirmation/token", UserController, :token)
    get("/reset/FleetHub/password", UserController, :default_password)
    get "/Users/On/Leave", UserController, :users_on_leave
    post "/Activate/Leave/Account", UserController, :activate_user_on_leave
  end




  scope "/", LoanSavingsSystemWeb do
    pipe_through([:browser, :no_layout])

    get("/logout/current/user", SessionController, :signout)
    get "/Account/Disabled", SessionController, :error_405
    get("/Login", SessionController, :new)
    post("/validate-otp", SessionController, :validate_otp)
    get("/new-user-set-password", SessionController, :new_user_set_password)
    post("/new_user_set_password", SessionController, :post_new_user_set_password)
    get("/loan/apply-for-a-loan", LoanController, :loan_product_guest)
    get("/new-user-role-set-otp", SessionController, :get_login_validate_otp)
    post("/Recover/Password", SessionController, :recover_password)
    get("/Recover/Password/confirm-OTP", SessionController, :get_forgot_password_validate_otp)
    post("/Forgot-Password/validate-otp", SessionController, :forgot_password_validate_otp)
    get("/Forgot-Password/User/set/Password", SessionController, :forgot_password_user_set_password)
    post("/Forgot-Password/new_user_set_password", SessionController, :forgot_password_post_new_user_set_password)
  end





  scope "/", LoanSavingsSystemWeb do
    pipe_through([:browser, :savings_admin_app])

    get("/Savings/dashboard", UserController, :savings_dashboard)
    get("/Savings/User/Logs", UserController, :user_logs)
    get("/Savings/USSD/Logs", UserController, :ussd_logs)
    post "/Savings/Create/User/Role", UserController, :create_roles
    get("/Savings/User/Management", UserController, :user_mgt)

    get("/Savings/all/users", UserController, :list_users)
    get("/Savings/new/user", UserController, :new)
    get "/Savings/Create/User", UserController, :create_user
    post "/Savings/Create/User", UserController, :create_user
    post("/Savings/new/user", UserController, :create)
    get("/Customer/User/Logs", UserController, :user_logs)

    get("/Savings/Products", ProductController, :savings_product)
    post("/Add/Savings/Products", ProductController, :add_savings_product)
    post("/Update/Savings/Products", ProductController, :update_savings_product)
    post("/Approve/Savings/Products", ProductController, :approve_savings_product)

    get("/Products/Divestment", ProductController, :divestment_package)
    post("/Add/Products/Divestment", ProductController, :add_divestment_package)
    post("/Update/Products/Divestment", ProductController, :update_divestment_package)
    post("/Approve/Products/Divestment", ProductController, :approve_divestment_package)

    get("/Savings/Accounts", LoanController, :savings_accounts)
    get("/Fixed/Deposits", LoanController, :fixed_deposits)
    get("/Fixed/Deposits/All", LoanController, :fixed_deps)
    get("/All/Transactions", LoanController, :transactions)
    get("/Customer/All", CustomerController, :all_customer)
    get("/Customer/Details", CustomerController, :customer_details)

    get("/View/Charges", MaintenanceController, :charge)
    post("/Add/Charges", MaintenanceController, :add_charge)

    post("/Generate/Random/Password", UserController, :generate_random_password)

    # --------------------------Brances
    get("/Maintenence/Branch", MaintenanceController, :branch)
    post("/Maintenence/Branch/Add", MaintenanceController, :add_branch)
    post("/Maintenence/Branch/Update", MaintenanceController, :update_branch)
    post("/Maintenence/Branch/Approve", MaintenanceController, :approve_branch)

    # --------------------------Currency
    get("/Maintenence/Currency", MaintenanceController, :currency)
    post("/Maintenence/Currency/Add", MaintenanceController, :add_currency)
    post("/Maintenence/Currency/Update", MaintenanceController, :update_currency)
    post("/Maintenence/Currency/Approve", MaintenanceController, :approve_currency)
    get("/Maintenence/Notifications", MaintenanceController, :notifications)
    post("/Maintenence/Notification/Add", MaintenanceController, :add_notification_config)
    get("/Maintenence/Questions", MaintenanceController, :questions)
    post("/Maintenence/Questions/Add", MaintenanceController, :add_questions)
    post("/Maintenence/Questions/Update", MaintenanceController, :update_questions)
    post("/Question/Disable", MaintenanceController, :question_disable)
    post("/Question/Activate", MaintenanceController, :question_activate)

    # --------------------------Countries
    get("/Maintenence/Country", MaintenanceController, :country)
    post("/Maintenence/Country", MaintenanceController, :handle_bulk_upload)

    get("/Divestment/Reports", ReportController, :divestment_reports)
    get("/old/Generate/Divestment/Reports", ReportController, :generate_divestment_reports)
    get("/Transaction/Reports", ReportController, :transaction_reports)
    get("/Generate/Transaction/Reports", ReportController, :generate_transaction_reports)
    get("/Fixeddeposit/Reports", ReportController, :fixed_deposit_reports)
    get("/Generate/FixedDeposit/Reports", ReportController, :generate_fixed_deposit_reports)
    get("/Customer/Reports", ReportController, :customer_reports)
    get("/Generate/ExpectedMaturity/Reports", ReportController, :generate_customer_reports)

    get("/Savings/Customer/Accounts", CustomerController, :all_savings_customer)

    get("/Savings/Customer/Disable/Ussd", CustomerController, :customer_disable_ussd)
    get("/Savings/Customer/Disable/Login", CustomerController, :customer_disable_login)
    get("/Savings/Customer/Enable/Ussd", CustomerController, :customer_enable_ussd)
    get("/Savings/Customer/Enable/Login", CustomerController, :customer_enable_login)


    get("/Savings/Run-End-Of-Day", EndOfDayRunController, :new)
    post("/Savings/Run-End-Of-Day", EndOfDayRunController, :create)
    get("/Savings/End-Of-Day-History", EndOfDayRunController, :index)
    get("/Savings/End-Of-Day-History-Entries/:endofdayid", EndOfDayRunController, :end_of_day_entries)
    get("/Savings/End-Of-Day-Configurations", EndOfDayRunController, :create_end_of_day_configurations)
    post("/Savings/End-Of-Day-Configurations", EndOfDayRunController, :post_create_end_of_day_configurations)



    get("/View/calendar", EndOfDayRunController, :index_calendar)
    post("/Add/calendar", EndOfDayRunController, :create_calendar)
    get("/view/holidays/:calendarId", EndOfDayRunController, :index_holiday)
    post("/Add/holiday", EndOfDayRunController, :create_holiday)


    get("/Savings/New-Flexcube-Account", FcubeGeneralLedgerController, :new)
    get("/Savings/New-Flexcube-Account/:accountId", FcubeGeneralLedgerController, :edit)
    post("/Savings/Update-Flexcube-Account", FcubeGeneralLedgerController, :create)
    get("/Savings/End-Of-Day-Configurations", FcubeGeneralLedgerController, :get_configurations)
    get("/Savings/View-Flexcube-Accounts", FcubeGeneralLedgerController, :index)
    get("/Savings/View-Flexcube-Requests", FcubeGeneralLedgerController, :index)


    post("/reset/password", UserController, :default_password)
    post("/reset/user/password", UserController, :reset_pwd)
    post("/Change/password", UserController, :change_password)
    get("/Change/password", UserController, :new_password)
	
	
    get("/Savings/confirm-fixed-deposit/:fixedDepositId", LoanController, :confirmFixedDeposit)


  end




  scope "/", LoanSavingsSystemWeb do
    pipe_through([:browser, :loans_admin_app])

      # ---------------------------Test
      # get("/User/Management", UserController, :user_mgt)
      # ----------------------------------------------------------------

      get("/Loans/dashboard", UserController, :dashboard)
      post("/Create/User/Roles", UserController, :add_user_roles)
      get("/User/Roles", UserController, :user_roles)
      get("/User/Logs", UserController, :user_logs)
      post "/Create/User/Role", UserController, :create_roles
      post("/Admin/Approve", UserController, :activate_admin)
      get("/Admin/Approve", UserController, :activate_admin)
      post("/Admin/Deactivate", UserController, :deactivate_admin)
      get("/Admin/Deactivate", UserController, :deactivate_admin)
      post("/Admin/Delete", UserController, :delete_admin)
      get("/Admin/Delete", UserController, :delete_admin)

      get("/all/users", UserController, :list_users)
      get("/new/user", UserController, :new)
      get("/User/Username", UserController, :username)
      get "/Create/User", UserController, :create_user
      post "/Create/User", UserController, :create_user
      post("/new/user", UserController, :create)

      # --------------------------Products
      get("/Loan/Products", ProductController, :loan_product)
      post("/Add/Loan/Products", ProductController, :add_loan_product)
      post("/Update/Loan/Products", ProductController, :update_loan_product)
      post("/Approve/Loan/Products", ProductController, :approve_loan_product)
      get("/View/Loans/Product", ProductController, :loans_under_product)
      post("/Create/Walkin/Customer", CustomerController, :create_walkin_customer)
      get("/Update/Customer/Bio", CustomerController, :update_individual)
      post("/Update/Walkin/Customer", CustomerController, :update_walkin_customer)
      post("/Bio/Approve", CustomerController, :approve_individual_bio)
      get("/Bio/Approve", CustomerController, :approve_individual_bio)

      # --------------------------Customers
      post("/Generate/Random/Password/Loan", UserController, :generate_random_password)
      get("/Loan/Customer/Details", CustomerController, :loan_customer_details)
      post("/Customer/Approve", CustomerController, :customer_approve)

      get("/All/Loan/Customer", CustomerController, :all_loan_customer)





      get("/Customer/Employer", CustomerController, :employer)
      post("/Add/Customer/Employer", CustomerController, :add_employer)
      post("/Edit/Employer", CustomerController, :update_employer)
      get("/Add/Employer/Admin", CustomerController, :employer_admin)
      post("/Create/Employer/User", UserController, :create_employer_admin)
      post("/employer/add-employer-role", UserController, :add_employer_admin_role)
      post("/Update/Employer/User", UserController, :update_employer_admin)
      post("/Employer/Approve", CustomerController, :approve_employer)

      # --------------------------Individual
      get("/Customer/individual", CustomerController, :individual)
      post("/Add/Individual", CustomerController, :add_individual)
      post("/Edit/Individual", CustomerController, :update_individual)
      post("/Approve/Individual", CustomerController, :approve_individual)

      # --------------------------SME
      get("/Customer/SME", CustomerController, :sme)
      post("/Add/SME", CustomerController, :add_sme)
      post("/Edit/SME", CustomerController, :update_sme)
      post("/Approve/SME", CustomerController, :approve_sme)
      get("/All/Loan/Transactions", LoanController, :all_loan_transactions)

      get("/Customer/Offtaker", CustomerController, :offtaker)
      post("/Add/Offtaker", CustomerController, :add_offtaker)
      post("/Offtaker/Approve", CustomerController, :approve_offtaker)
      post("/Edit/Offtaker", CustomerController, :update_offtaker)
      get("/Add/Offtaker/Admin", CustomerController, :offtaker_admin)
      post("/Create/Offtaker/User", UserController, :create_offtaker_admin)
      post("/Update/Offtaker/User", UserController, :update_offtaker_admin)

      # --------------------------Loans
      get("/Loans/Accounts", LoanController, :loans_accounts_for_bank_staff)
      get("/Loans/Pending", LoanController, :pending_loans)
      get("/Loans/Counter/Payments", LoanController, :counter_payments)
      get("/Loans/Accounts/:loanId", LoanController, :loan_details_for_bank_staff)


      # --------------------------User Management
      get("/Active/System/Users", UserController, :active_users)
      get("/Inactive/System/Users", UserController, :inactive_users)

      # --------------------------System Configurations
      get("/Settings/MNO", SystemController, :mno)
      post("/Add/MNO/Settings", SystemController, :add_mno_settings)
      get("/Settings/API", SystemController, :api)
      post("/Add/API/Settings", SystemController, :add_api_settings)
      get("/Settings/CBS", SystemController, :bank)
      post("/Add/Bank/Settings", SystemController, :add_bank_settings)
      get("/System/Configurations", SystemController, :system_configurations)

      # --------------------------Reports
      get("/Reports/Loans", ReportController, :loans_report)
      get("/Generate/Reports/Loans", ReportController, :generate_loan_reports)

      # --------------------------Documents
      get("/Maintenence/Document", MaintenanceController, :document)
      post("/Maintenence/Document/Add", MaintenanceController, :add_document)
      post("/Maintenence/Document/Update", MaintenanceController, :update_document)
      post("/Maintenence/Document/Approve", MaintenanceController, :approve_document)
  end



  scope "/", LoanSavingsSystemWeb do
    pipe_through([:browser, :employee_app])

     get("/Employee/dashboard", UserController, :employee_dashboard)
    # get("/Employee/User/Management", UserController, :user_mgt)
    # get("/Employee/User/Logs", UserController, :user_logs)
    # get "/Employee/User/Roles", UserController, :user_roles
    # post "/Employee/Create/User/Role", UserController, :create_roles

    # get("/Employee/all/users", UserController, :list_users)
    # get("/Employee/new/user", UserController, :new)
    # get "/Employee/Create/User", UserController, :create_user
    # post("/Employee/new/user", UserController, :create)


    get("/Employee/loan/apply-for-a-loan", LoanController, :loan_product)
    get("/Employee/loan/view-terms-conditions", LoanController, :terms_conditions)
    get("/Employee/loan/view/direct_debit", LoanController, :direct_debit)
    get("/Employee/loan/create-new-loan", LoanController, :createNewLoan)

    get("/Employee/loans", LoanController, :loans_accounts)
    get("/Employee/Loans/Accounts/:loanId", LoanController, :loan_details)
    post("/Employee/Loans/Accounts/:loanId", LoanController, :admin_approve_loan)

    get("/Employee/Pending/loans", LoanController, :employee_pending_loans)
    get("/Employee/loans/Repayment", LoanController, :employee_loans_repayments)
  end




  scope "/", LoanSavingsSystemWeb do
    pipe_through([:browser, :employer_app])

    get("/Employer/dashboard", UserController, :employer_dashboard)
    # get("/Employer/User/Management", UserController, :user_mgt)
    get "/Employer/User/Roles", UserController, :user_roles
    post "/Employer/Create/User/Role", UserController, :create_roles

    get("/Employer/all/users", UserController, :list_users)
    get("/Employer/new/user", UserController, :new)
    get "/Employer/Create/User", UserController, :create_user
    post("/Employer/new/user", UserController, :create)


    get("/Employer/Customer/Employee", CustomerController, :employer_staff)
    post("/Employer/Customer/Employee", CustomerController, :handle_bulk_upload_of_employee)
    post("/Employer/Add/Customer/Employee", CustomerController, :add_employee)
    post("/Employer/Edit/Employee", CustomerController, :update_employee)
    post("/Employer/Employee/Approve", CustomerController, :approve_employee)
    get("/Add/Employer/Staff", CustomerController, :employer_staff)
    post("/Add/Employer/Staff", CustomerController, :employer_staff)
    post("/Add/Employer/Employee", CustomerController, :add_employer_employee)
    post("/Edit/Employer/Employee", CustomerController, :update_employer_employee)
    post("/employer/add-employer-employee-role", UserController, :add_employer_employee_role)

    get("/Employer/loans", LoanController, :loans_accounts_for_employer)
    get("/Employer/Loans/Accounts/:loanId", LoanController, :loan_details)
    post("/Employer/company-admin/loans/accounts/:loanId", LoanController, :company_admin_approve_loan)
    get("/Employer/loans/Repayments", LoanController, :loans_repayments_for_employer)
    post("/Employer/Scheduled/loan/Repayment", LoanController, :employer_scheduled_loan_repayment)

  end

  scope "/", LoanSavingsSystemWeb do
    pipe_through([:browser, :individual_app])

    get("/Login", SessionController, :new)
    post("/validate-otp", SessionController, :validate_otp)
    get("/new-user-role-set-otp", SessionController, :get_login_validate_otp)
    get("/new-user-set-password", SessionController, :new_user_set_password)
    post("/new_user_set_password", SessionController, :post_new_user_set_password)
    get("/individual/loan/apply-for-a-loan", LoanController, :loan_product)
    get("/view/terms/conditions", LoanController, :terms_conditions)
    get("/view/direct_debit", LoanController, :direct_debit)
    get("/loans/individual/create-new-loan", LoanController, :createNewLoan)
  end

  scope "/", LoanSavingsSystemWeb do
    pipe_through([:api, :no_layout])
    get("/emulator-ussd", UssdController, :index)
    get("/appusers", UssdController, :index)
    get("/ussd", UssdController, :initiateUssd)
    get("/api/get-loan-product-by-id", ProductController, :getLoanProductById)
    get("/api/calculate-loan-details", ProductController, :getCalculateLoanDetails)
    get("/api/user/get-user-bio-data-by-id-ajax/:bioDataId", UserController, :getUserBioDataById)
    get("/api/user/get-user-addresses-by-user-id-ajax/:userId", UserController, :getUserAddressesById)
    get("/api/user/get-user-next-of-kin-by-user-id-ajax/:userId", UserController, :getNextOfKinByUserId)
    get("/api/user/get-employer-user-by-mobile-number-and-role-type-ajax/:companyId/:mobileNumber/:roleType", UserController, :getEmployerUserByMobileNumberAndRoleType)
    get("/api/user/get-bank-staff-by-mobile-number-and-role-type-ajax/:mobileNumber", UserController, :getBankStaffByMobileNumber)
    get("/api/user/get-bank-staff-by-branch-id/:branchId", UserController, :getBankStaffByBranchId)
    get("/api/workflows/get-workflow-members/:workflowId", UserController, :getWorkflowMembersByWorkflowId)
  end

  # Other scopes may use custom stacks.
  # scope "/api", LoanSavingsSystemWeb do
  #   pipe_through :api
  # end
end
