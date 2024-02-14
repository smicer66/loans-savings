defmodule LoanSavingsSystemWeb.UserController do
  use LoanSavingsSystemWeb, :controller
  use Ecto.Schema
  alias LoanSavingsSystem.Repo
  import Ecto.Query, warn: false
  alias LoanSavingsSystem.Accounts
  alias LoanSavingsSystem.Accounts.User
  alias LoanSavingsSystem.Accounts.UserRole
  alias LoanSavingsSystem.Client.UserBioData
  alias LoanSavingsSystem.Emails.Email
  alias LoanSavingsSystem.Logs.UserLogs
  alias LoanSavingsSystem.Notifications.Sms
  alias LoanSavingsSystem.Accounts.BankStaffRole
  alias LoanSavingsSystem.{Logs, Repo, Logs.UserLogs}
  alias LoanSavingsSystem.Auth
  require Logger

  plug(
    LoanSavingsSystemWeb.Plugs.EnforcePasswordPolicy
      when action not in [:new_password, :change_password]
    )

  def user_creation(conn, _params) do
    render(conn, "user_mgt.html")
  end

  def generate_otp do
    random_int = to_string(Enum.random(1111..9999))
    random_int
  end


  def get_user_by_email(username) do
    case Repo.get_by(User, username: username) do
      nil -> {:error, "invalid User Name address"}
      user -> {:ok, user}
    end
  end

  def get_user_by_user_role(userId) do
    case Accounts.get_users(userId) do
      nil -> {:error, "invalid User Name address"}
     user ->
      user
    end
  end

  def employee_dashboard(conn, _params) do
    users = Accounts.list_tbl_users()
  #  user = Accounts.get_user!(conn.assigns.user.id).id
  # last_logged_in = Logs.last_logged_in(user)
    render(conn, "employee_dashboard.html", users: users)
  end

  def employer_dashboard(conn, _params) do
    current_user_role = get_session(conn, :current_user_role)
    query = from cl in LoanSavingsSystem.Companies.Company, where: cl.id == ^current_user_role.companyId, select: cl
        company = Repo.all(query);
        company = Enum.at(company, 0)
    users = Accounts.list_tbl_users()
  #  user = Accounts.get_user!(conn.assigns.user.id).id
  # last_logged_in = Logs.last_logged_in(user)
    render(conn, "employer_dashboard.html", users: users, company: company)
  end

  def create_user(conn, %{"username" => username} = params) do
    params = Map.put(params, "status", "ACTIVE")
    params = Map.put(params, "auto_password", "Y")
    get_username = Repo.get_by(User, username: username)
    case is_nil(get_username) do
      true ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:create_user, User.changeset(%User{}, params))
        |> Ecto.Multi.run(:user_role, fn (_, %{create_user: user}) ->

            generate_otp = to_string(Enum.random(1111..9999))
          #Push Data To User Roles
          user_role = %{
            userId: user.id,
            roleType: params["roleType"],
            clientId: conn.assigns.user.clientId,
            status: user.status,
            otp: generate_otp
          }
          UserRole.changeset(%UserRole{}, user_role)
          |> Repo.insert()

        end)
        |> Ecto.Multi.run(:user_bio_data, fn (_, %{create_user: user}) ->
            #Push Data To Bio Data
            user_bio_data = %{
              firstName: params["firstName"],
              lastName: params["lastName"],
              userId: user.id,
              otherName: params["otherName"],
              dateOfBirth: params["dateOfBirth"],
              meansOfIdentificationType: params["meansOfIdentificationType"],
              meansOfIdentificationNumber: params["meansOfIdentificationNumber"],
              title: params["title"],
              gender: params["gender"],
              mobileNumber: params["username"],
              emailAddress: user.username,
              clientId: conn.assigns.user.clientId,
            }
          UserBioData.changeset(%UserBioData{}, user_bio_data)
          |> Repo.insert()
        end)
        |> Ecto.Multi.run(:user_log, fn (_, %{create_user: user}) ->
          activity = "created user with id \"#{user.id}\" "
            #Push Data To User Logs
            user_log = %{
              user_id: conn.assigns.user.id,
              activity: activity
            }

            UserLogs.changeset(%UserLogs{}, user_log)
            |> Repo.insert()
        end)
        |> Ecto.Multi.run(:sms, fn (_, %{user_bio_data: bio_data, user_role: user_role}) ->
          otp = user_role.otp
          sms = %{
            mobile: bio_data.mobileNumber,
            msg: "Dear customer, Your Login Credentials. username: #{params["username"]}, password: #{params["password"]}, OTP: #{otp}",
            status: "READY",
            type: "SMS",
            msg_count: "1",
            }
            Sms.changeset(%Sms{}, sms)
            |> Repo.insert()
        end)
        |> Repo.transaction()
          |> case do
            {:ok, %{create_user: _user, user_log: _user_log}} ->
              Email.send_email(params["emailAddress"], params["password"], params["firstName"])

              conn
              |> put_flash(:info, "Bank Staff User Account created Successfully")
              |> redirect(to: Routes.user_path(conn,  :user_mgt))

            {:error, _failed_operation, failed_value, _changes} ->
              reason = traverse_errors(failed_value.errors) |> List.first()

              conn
                |> put_flash(:error, reason)
                |> redirect(to: Routes.user_path(conn,  :user_mgt))

          end
      _ ->
        # userId = Enum.at(get_username, 0).id;
        # roleType = params["roleType"];
        # #get_userrole = Repo.get_by(UserRole, userId: userId)#, roleType: roleType}
        # get_userrole =
        # User
        #   |> where(userId: ^userId)
        #   |> where(roleType: ^roleType)
        #   |> Repo.one
        # case is_nil(get_userrole) do
        #   true ->
        #     create_new_user_role_for_existing_user(conn, params, userId)

        #   _ ->
        #     conn
        #     |> put_flash(:error, "User Role Already Exists")
        #     |> redirect(to: Routes.user_path(conn,  :user_mgt))
        # end
        conn
            |> put_flash(:error, "User Role Already Exists")
            |> redirect(to: Routes.user_path(conn,  :user_mgt))
    end

  end

  def create_new_user_role_for_existing_user(conn, params, userId) do
    generate_otp = to_string(Enum.random(1111..9999))
    #Push Data To User Roles
    user_role = %{
      userId: userId,
      roleType: params["roleType"],
      clientId: conn.assigns.user.clientId,
      status: conn.assigns.user.status,
      otp: generate_otp
    }
    UserRole.changeset(%UserRole{}, user_role)
    |> Repo.insert()

    #Push Data To Bio Data
    user_bio_data = %{
      firstName: params["firstName"],
      lastName: params["lastName"],
      userId: userId,
      otherName: params["otherName"],
      dateOfBirth: params["dateOfBirth"],
      meansOfIdentificationType: params["meansOfIdentificationType"],
      meansOfIdentificationNumber: params["meansOfIdentificationNumber"],
      title: params["title"],
      gender: params["gender"],
      mobileNumber: params["mobileNumber"],
      emailAddress: params["emailAddress"],
      clientId: params["clientId"],
    }
    UserBioData.changeset(%UserBioData{}, user_bio_data)
    |> Repo.insert()

    |> Repo.transaction()
    |> case do
      {:ok, %{create_user: _user}} ->
        conn
        |> put_flash(:info, "User created Successfully")
        |> redirect(to: Routes.user_path(conn,  :user_mgt))

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to create user.")
        |> redirect(to: Routes.user_path(conn,  :user_mgt))
    end
  end

  def savings_dashboard(conn, _params) do
    users = Accounts.list_tbl_users()
    get_bio_datas = Accounts.get_logged_user_details
  #  user = Accounts.get_user!(conn.assigns.user.id).id
  # last_logged_in = Logs.last_logged_in(user)
    render(conn, "savings_dashboard.html", users: users, get_bio_datas: get_bio_datas)
  end

  def dashboard(conn, _params) do
    users = Accounts.list_tbl_users()
    get_bio_datas = Accounts.get_logged_user_details
  #  user = Accounts.get_user!(conn.assigns.user.id).id
  # last_logged_in = Logs.last_logged_in(user)
    render(conn, "dashboard.html", users: users, get_bio_datas: get_bio_datas)
  end

  def user_mgt(conn, _params) do
    bank_roles = Accounts.list_tbl_bank_staff_role()
    system_users = Accounts.list_tbl_users()
    get_bio_datas = Accounts.get_logged_user_details
  # roles = Accounts.list_tbl_user_role()
    render(conn, "user_mgt.html", system_users: system_users, get_bio_datas: get_bio_datas, bank_roles: bank_roles)
  end

  def savings_user_mgt(conn, _params) do
    bank_roles = Accounts.list_tbl_bank_staff_role()
    system_users = Accounts.list_tbl_users()
    get_bio_datas = Accounts.get_logged_user_details
  # roles = Accounts.list_tbl_user_role()
    render(conn, "user_mgt.html", system_users: system_users, get_bio_datas: get_bio_datas, bank_roles: bank_roles)
  end













  def user_roles(conn, _params) do
    bank_roles = Accounts.list_tbl_bank_staff_role()
    render(conn, "user_roles.html", bank_roles: bank_roles)
  end

  def add_user_roles(conn, params) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user_roles, BankStaffRole.changeset(%BankStaffRole{}, params))
    |> Ecto.Multi.run(:user_log, fn _repo, %{user_roles: user_roles} ->
      activity = "Created new Branch with ID \"#{user_roles.id}\""

      user_log = %{
            user_id: conn.assigns.user.id,
            activity: activity
      }

      UserLogs.changeset(%UserLogs{}, user_log)
      |> Repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user_roles: _user_roles, user_log: _user_log}} ->
        conn
        |> put_flash(:info, "New Bank User Role Created successfully.")
        |> redirect(to: Routes.user_path(conn, :user_roles))

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        reason = traverse_errors(failed_value.errors) |> List.first()

        conn
        |> put_flash(:error, reason)
        |> redirect(to: Routes.user_path(conn, :user_roles))
    end
    # rescue
    #   _ ->
    #     conn
    #     |> put_flash(:error, "An error occurred, reason unknown. try again")
    #     |> redirect(to: Routes.branch_path(conn, :index))
  end

  def activate_admin(conn, params) do
    users_approve = Accounts.get_user!(params["id"])
    Ecto.Multi.new()
    |> Ecto.Multi.update(:users, User.changeset(users_approve, %{status: "ACTIVE" }))
    |> Ecto.Multi.run(:user_log, fn (_, %{users: _users}) ->
        activity = "User Activated"

        user_logs = %{
          user_id: conn.assigns.user.id,
          activity: activity
        }

        UserLogs.changeset(%UserLogs{}, user_logs)
        |> Repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{users: _users, user_log: _user_log}} ->
        conn |> json(%{message: "Savings Product approved successfully", status: 0})
        {:error, _failed_operation, failed_value, _changes_so_far} ->
          reason = traverse_errors(failed_value.errors) |> List.first()
          conn |> json(%{message: reason, status: 1})
    end
  end

  def deactivate_admin(conn, params) do
    users_approve = Accounts.get_user!(params["id"])
    Ecto.Multi.new()
    |> Ecto.Multi.update(:users, User.changeset(users_approve, %{status: "DEACTIVATED" }))
    |> Ecto.Multi.run(:user_log, fn (_, %{users: _users}) ->
        activity = "Account Deactivated"

        user_logs = %{
          user_id: conn.assigns.user.id,
          activity: activity
        }

        UserLogs.changeset(%UserLogs{}, user_logs)
        |> Repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{users: _users, user_log: _user_log}} ->
        conn |> json(%{message: "Account Deativated successfully", status: 0})
        {:error, _failed_operation, failed_value, _changes_so_far} ->
          reason = traverse_errors(failed_value.errors) |> List.first()
          conn |> json(%{message: reason, status: 1})
    end
  end

  def delete_admin(conn, params) do
    users_approve = Accounts.get_user!(params["id"])
    Ecto.Multi.new()
    |> Ecto.Multi.update(:users, User.changeset(users_approve, %{status: "BLOCKED" }))
    |> Ecto.Multi.run(:user_log, fn (_, %{users: _users}) ->
        activity = "Account Deleted"

        user_logs = %{
          user_id: conn.assigns.user.id,
          activity: activity
        }

        UserLogs.changeset(%UserLogs{}, user_logs)
        |> Repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{users: _users, user_log: _user_log}} ->
        conn |> json(%{message: "Account Deativated successfully", status: 0})
        {:error, _failed_operation, failed_value, _changes_so_far} ->
          reason = traverse_errors(failed_value.errors) |> List.first()
          conn |> json(%{message: reason, status: 1})
    end
  end




  def getEmployerUserByMobileNumberAndRoleType(conn, params) do
      mobileNumber = params["mobileNumber"];
      roleType = params["roleType"];
      companyId = params["companyId"];
      userStatus = "ACTIVE";

      query = from cl in LoanSavingsSystem.Accounts.User, where: (cl.username== ^mobileNumber and cl.status == ^userStatus), select: cl
      users = Repo.all(query);

      if(Enum.count(users)==0) do
          response = %{
              status: 0
          }
          LoanSavingsSystemWeb.ProductController.send_response(conn, response);
      else
          user = Enum.at(users, 0);
          query = from cl in LoanSavingsSystem.Accounts.UserRole, where: (cl.userId== ^user.id and cl.roleType == ^roleType and
                  cl.companyId == ^companyId and cl.status == ^userStatus), select: cl
          userRoles = Repo.all(query);
          if(Enum.count(userRoles)==0) do
              query = from cl in LoanSavingsSystem.Client.UserBioData, where: (cl.userId== ^user.id), select: cl
              userBioDatas = Repo.all(query);
              userBioData = Enum.at(userBioDatas, 0);


              query = from cl in LoanSavingsSystem.Accounts.UserRole, where: (cl.userId== ^user.id and
                  cl.companyId == ^companyId and cl.status == ^userStatus), select: cl.roleType
              userRoles = Repo.all(query);

              response = %{
                  status: 1,
                  userBioData: userBioData,
                  userRoles: Enum.join(userRoles, ", ")
              }
              LoanSavingsSystemWeb.ProductController.send_response(conn, response);
          else
              response = %{
                  status: -1,
                  message: "A company administrator of the same company having the same number already exists"
              }
              LoanSavingsSystemWeb.ProductController.send_response(conn, response);
          end
      end




  end








  def create_employer_admin(conn, params) do
    current_user = get_session(conn, :current_user);
    mobileNumber = params["mobileNumber"];
    companyId = params["companyId"];
    title = params["title"];
    first_name = params["first_name"];
    last_name = params["last_name"];
    email = params["email"];
    id_type = params["id_type"];
    id_no = params["id_no"];
    address = params["address"];
    sex = params["sex"];
    user_role = params["user_role"];
    age = params["age"];
    userStatus = "ACTIVE";
    roleType = "COMPANY ADMIN"
    clientId = get_session(conn, :client_id)

    query = from cl in LoanSavingsSystem.Accounts.User, where: (cl.username== ^mobileNumber and cl.status == ^userStatus), select: cl
    users = Repo.all(query);

    Logger.info "User Count ... #{Enum.count(users)}"

    if(Enum.count(users)==0) do

        query = from cl in LoanSavingsSystem.Companies.Company, where: (cl.id== ^companyId), select: cl
        companies = Repo.all(query);
        company = Enum.at(companies, 0);
        registrationNumber = company.registrationNumber

        current_user = get_session(conn, :current_user);
        mobileNumber = params["mobileNumber"];
        companyId = params["companyId"];
        title = params["title"];
        first_name = params["first_name"];
        last_name = params["last_name"];
        email = params["email"];
        id_type = params["id_type"];
        id_no = params["id_no"];
        address = params["address"];
        sex = params["sex"];
        user_role = params["user_role"];
        age = params["age"];
        userStatus = "ACTIVE";
        roleType = "COMPANY ADMIN"
        clientId = get_session(conn, :client_id)
        age = Date.from_iso8601!(age)

        user = %LoanSavingsSystem.Accounts.User{
            username: mobileNumber,
            clientId: conn.assigns.user.clientId,
            createdByUserId: current_user,
            status: userStatus,
        }

        case Repo.insert(user) do
            {:ok, user} ->
                user_bio_data = %LoanSavingsSystem.Client.UserBioData{
                    firstName: first_name,
                    lastName: last_name,
                    userId: user.id,
                    otherName: nil,
                    dateOfBirth: (age),
                    meansOfIdentificationType: id_type,
                    meansOfIdentificationNumber: id_no,
                    title: title,
                    gender: sex,
                    mobileNumber: mobileNumber,
                    emailAddress: email,
                    clientId: conn.assigns.user.clientId,
                }
                case Repo.insert(user_bio_data) do
                    {:ok, user_bio_data} ->
                        otp = Enum.random(1_000..9_999)
                        otp = Integer.to_string(otp)


                        appUserRole = %LoanSavingsSystem.Accounts.UserRole{
                            clientId: clientId,
                            roleType: roleType,
                            status: "ACTIVE",
                            userId: user.id,
                            companyId: company.id,
                            otp: otp
                        }
                        case Repo.insert(appUserRole) do
                            {:ok, appUserRole} ->
                                conn
                                  |> put_flash(:info, "Company Administrator role has been created for the user")
                                  |> redirect(to: "/Add/Employer/Admin?company_id=#{registrationNumber}")
                            {:error, changeset} ->
                                conn
                                  |> put_flash(:info, "Company Administrator role could not be be created for the user")
                                  |> redirect(to: "/Add/Employer/Admin?company_id=#{registrationNumber}")
                        end
                    {:error, changeset} ->
                        conn
                          |> put_flash(:info, "Company Administrator profile could not be be created for the user")
                          |> redirect(to: "/Add/Employer/Admin?company_id=#{registrationNumber}")
                end
            {:error, changeset} ->
                conn
                  |> put_flash(:info, "Company Administrator profile could not be be created for the user")
                  |> redirect(to: "/Add/Employer/Admin?company_id=#{registrationNumber}")
        end


    else
        us = Enum.at(users, 0);

        query = from cl in LoanSavingsSystem.Companies.Company, where: (cl.id== ^companyId), select: cl
        companies = Repo.all(query);
        company = Enum.at(companies, 0);
        registrationNumber = company.registrationNumber

        conn
          |> put_flash(:error, "Use the option to add a role to this user instead")
          |> redirect(to: "/Add/Employer/Admin?company_id=#{registrationNumber}")

    end
end



def add_employer_admin_role(conn, params) do
    mobileNumber = params["mobileNumber"];
    companyId = params["companyId"];
    userStatus = "ACTIVE";
    roleType = "COMPANY ADMIN"
    clientId = get_session(conn, :client_id)

    query = from cl in LoanSavingsSystem.Accounts.User, where: (cl.username== ^mobileNumber and cl.status == ^userStatus), select: cl
    users = Repo.all(query);

    if(Enum.count(users)==0) do
        response = %{
            status: 0
        }
        LoanSavingsSystemWeb.ProductController.send_response(conn, response);
    else
        user = Enum.at(users, 0);
        query = from cl in LoanSavingsSystem.Companies.Company, where: (cl.id== ^companyId), select: cl
        companies = Repo.all(query);
        company = Enum.at(companies, 0);
        registrationNumber = company.registrationNumber

        query = from cl in LoanSavingsSystem.Accounts.UserRole, where: (cl.userId== ^user.id and cl.roleType == ^roleType and
                cl.companyId == ^companyId and cl.status == ^userStatus), select: cl
        userRoles = Repo.all(query);
        if(Enum.count(userRoles)==0) do
            otp = Enum.random(1_000..9_999)
            otp = Integer.to_string(otp)


            appUserRole = %LoanSavingsSystem.Accounts.UserRole{
                clientId: clientId,
                roleType: roleType,
                status: "ACTIVE",
                userId: user.id,
                companyId: company.id,
                otp: otp
            }
            case Repo.insert(appUserRole) do
                {:ok, appUserRole} ->
                    conn
                      |> put_flash(:info, "Company Administrative role has been added to the users profile")
                      |> redirect(to: "/Add/Employer/Admin?company_id=#{registrationNumber}")
                {:error, changeset} ->
                    conn
                      |> put_flash(:info, "Company Administrative role could not be been added to the users profile")
                      |> redirect(to: "/Add/Employer/Admin?company_id=#{registrationNumber}")
            end

        else
            response = %{
                status: -1,
                message: "A company administrator of the same company having the same number already exists"
            }
            LoanSavingsSystemWeb.ProductController.send_response(conn, response);
        end
    end
end


def add_employer_employee_role(conn, params) do
    mobileNumber = params["mobileNumber"];
    companyId = params["companyId"];
    netPay = params["netPay"];
    userStatus = "ACTIVE";
    roleType = "EMPLOYEE"
    clientId = get_session(conn, :client_id)
    netPay = elem Float.parse(netPay), 0

    query = from cl in LoanSavingsSystem.Accounts.User, where: (cl.username== ^mobileNumber and cl.status == ^userStatus), select: cl
    users = Repo.all(query);

    if(Enum.count(users)==0) do
        response = %{
            status: 0
        }
        LoanSavingsSystemWeb.ProductController.send_response(conn, response);
    else
        user = Enum.at(users, 0);
        query = from cl in LoanSavingsSystem.Companies.Company, where: (cl.id== ^companyId), select: cl
        companies = Repo.all(query);
        company = Enum.at(companies, 0);
        registrationNumber = company.registrationNumber

        query = from cl in LoanSavingsSystem.Accounts.UserRole, where: (cl.userId== ^user.id and cl.roleType == ^roleType and
                cl.companyId == ^companyId and cl.status == ^userStatus), select: cl
        userRoles = Repo.all(query);
        if(Enum.count(userRoles)==0) do
            otp = Enum.random(1_000..9_999)
            otp = Integer.to_string(otp)


            appUserRole = %LoanSavingsSystem.Accounts.UserRole{
                clientId: clientId,
                roleType: roleType,
                status: "ACTIVE",
                userId: user.id,
                companyId: company.id,
                otp: otp,
                netPay: netPay
            }
            case Repo.insert(appUserRole) do
                {:ok, appUserRole} ->
                    conn
                      |> put_flash(:info, "Company Employee role has been added to the users profile")
                      |> redirect(to: "/Add/Employer/Staff?company_id=#{companyId}")
                {:error, changeset} ->
                    conn
                      |> put_flash(:info, "Company Employee role could not be been added to the users profile")
                      |> redirect(to: "/Add/Employer/Staff?company_id=#{companyId}")
            end

        else
            response = %{
                status: -1,
                message: "A company employee of the same company having the same number already exists"
            }
            LoanSavingsSystemWeb.ProductController.send_response(conn, response);
        end
    end
end





def getUserBioDataById(conn, params) do
  bioDataId = params["bioDataId"];


  query = from cl in LoanSavingsSystem.Client.UserBioData, where: (cl.id== ^bioDataId), select: cl
      userBioData = Repo.all(query);
      userBioData = Enum.at(userBioData, 0);

  uB = %{"First Name"=>userBioData.firstName, "Last Name"=>userBioData.lastName, "Date Of Birth"=>userBioData.dateOfBirth,
      "Means Of Identification Type"=>userBioData.meansOfIdentificationType, "Means Of Identification Number"=>userBioData.meansOfIdentificationNumber,
      "Mobile Number"=>userBioData.mobileNumber, "Email Address"=>userBioData.emailAddress
  };

  response = %{
      bioData: uB,
      status: 1
  }

  LoanSavingsSystemWeb.ProductController.send_response(conn, response);
end


def getUserAddressesById(conn, params) do
  userId = params["userId"];


  query = from cl in LoanSavingsSystem.Client.Address, where: (cl.userId== ^userId), order_by: [desc: cl.isCurrent], select: cl
      addresses = Repo.all(query);

  response = %{
      addresses: addresses,
      status: 1
  }

  LoanSavingsSystemWeb.ProductController.send_response(conn, response);
end



def getNextOfKinByUserId(conn, params) do
  userId = params["userId"];


  query = from cl in LoanSavingsSystem.Client.NextOfKin, where: (cl.userId== ^userId), order_by: [desc: cl.inserted_at], select: cl
      nextOfKins = Repo.all(query);

  response = %{
      nextOfKins: nextOfKins,
      status: 1
  }

  LoanSavingsSystemWeb.ProductController.send_response(conn, response);
end



def getEmployerUserByMobileNumberAndRoleType(conn, params) do
  mobileNumber = params["mobileNumber"];
  roleType = params["roleType"];
  companyId = params["companyId"];
  userStatus = "ACTIVE";

  query = from cl in LoanSavingsSystem.Accounts.User, where: (cl.username== ^mobileNumber and cl.status == ^userStatus), select: cl
  users = Repo.all(query);

  if(Enum.count(users)==0) do
      response = %{
          status: 0
      }
      LoanSavingsSystemWeb.ProductController.send_response(conn, response);
  else
      user = Enum.at(users, 0);
      query = from cl in LoanSavingsSystem.Accounts.UserRole, where: (cl.userId== ^user.id and cl.roleType == ^roleType and
              cl.companyId == ^companyId and cl.status == ^userStatus), select: cl
      userRoles = Repo.all(query);
      if(Enum.count(userRoles)==0) do
          query = from cl in LoanSavingsSystem.Client.UserBioData, where: (cl.userId== ^user.id), select: cl
          userBioDatas = Repo.all(query);
          userBioData = Enum.at(userBioDatas, 0);


          query = from cl in LoanSavingsSystem.Accounts.UserRole, where: (cl.userId== ^user.id and
              cl.companyId == ^companyId and cl.status == ^userStatus), select: cl.roleType
          userRoles = Repo.all(query);

          response = %{
              status: 1,
              userBioData: userBioData,
              userRoles: Enum.join(userRoles, ", ")
          }
          LoanSavingsSystemWeb.ProductController.send_response(conn, response);
      else
          response = %{
              status: -1,
              message: "A company administrator of the same company having the same number already exists"
          }
          LoanSavingsSystemWeb.ProductController.send_response(conn, response);
      end
  end
end

def new_password(conn, _params) do
  page = %{first: "Settings", last: "Change password"}
  render(conn, "change_password.html", page: page)
end

def change_password(conn, %{"user" => user_params}) do
  case confirm_old_password(conn, user_params) do
    false ->
      conn
      |> put_flash(:error, "some fields were submitted empty!")
      |> redirect(to: Routes.user_path(conn, :new_password))

    result ->
      with {:error, reason} <- result do
        conn
        |> put_flash(:error, reason)
        |> redirect(to: Routes.user_path(conn, :new_password))
      else
        {:ok, _} ->
          conn.assigns.user
          |> change_pwd(user_params)
          |> Repo.transaction()
          |> case do
            {:ok, %{update: _update, insert: _insert}} ->
              conn
              |> put_flash(:info, "Password changed successful")
              |> redirect(to: Routes.user_path(conn, :savings_dashboard))

            {:error, _failed_operation, failed_value, _changes_so_far} ->
              reason = traverse_errors(failed_value.errors) |> List.first()

              conn
              |> put_flash(:error, reason)
              |> redirect(to: Routes.user_path(conn, :new_password))
          end
      end
  end
# rescue
#   _ ->
#     conn
#     |> put_flash(:error, "Password changed with errors")
#     |> redirect(to: Routes.user_path(conn, :new_password))
end

def change_pwd(user, user_params) do
  pwd = String.trim(user_params["new_password"])

  Ecto.Multi.new()
  |> Ecto.Multi.update(:update, User.changeset(user, %{password: pwd, auto_password: "N"}))
  |> Ecto.Multi.insert(
    :insert,
    UserLogs.changeset(
      %UserLogs{},
      %{user_id: user.id, activity: "changed account password"}
    )
  )
end

defp confirm_old_password(
       conn,
       %{"old_password" => pwd, "new_password" => new_pwd}
     ) do
  # IO.inspect("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
  # IO.inspect conn

  with true <- String.trim(pwd) != "",
       true <- String.trim(new_pwd) != "" do
    Auth.confirm_password(
      conn.assigns.user,
      String.trim(pwd)
    )
  else
    false -> false
  end
end


  def password_render() do
    random_string()
  end

  def number do
    spec =Enum.to_list(?2..?9)
    length = 2
    Enum.take_random(spec, length)
  end
  def number2 do
    spec =Enum.to_list(?1..?9)
    length = 1
    Enum.take_random(spec, length)
  end
  def caplock do
    spec = Enum.to_list(?A..?N)
    length = 1
    Enum.take_random(spec, length)
  end
  def small_latter do
    spec = Enum.to_list(?a..?n)
    length = 1
    Enum.take_random(spec, length)
  end
  def small_latter2 do
    spec = Enum.to_list(?p..?z)
    length = 2
    Enum.take_random(spec, length)
  end
  def special do
    spec = Enum.to_list(?#..?*)
    length = 1
    Enum.take_random(spec, length)|> to_string()|> String.replace("'", "^")|> String.replace("(", "!")|> String.replace(")", "@")
  end

  def random_string do
    smll = to_string(small_latter())
    smll2 = to_string(small_latter2())
    nmb = to_string(number())
    nmb2 = to_string(number2())
    spc = to_string(special())
    cpl = to_string(caplock())
    smll<>""<>nmb<>""<>spc<>""<>cpl<>""<>nmb2<>""<>smll2
  end

  def generate_random_password(conn, _param) do
    account = random_string()
    json(conn, %{"account" => account})
  end

  def user_logs(conn, _params) do
    user_activity = Logs.list_tbl_user_activity_logs()
    render(conn, "user_logs.html", user_activity: user_activity)
  end

  def ussd_logs(conn, _params) do
    query = from au in LoanSavingsSystem.UssdLogs.UssdLog,
		join: userBioData in UserBioData,
		on:
		au.userId == userBioData.userId,
		select: %{au: au, userBioData: userBioData}
	ussdLogs = Repo.all(query);
    render(conn, "ussd_logs.html", ussdLogs: ussdLogs)
  end

  def traverse_errors(errors) do
    for {key, {msg, _opts}} <- errors, do: "#{String.upcase(to_string(key))} #{msg}"
  end

end
