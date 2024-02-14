defmodule LoanSavingsSystemWeb.UssdController do
    use LoanSavingsSystemWeb, :controller
    alias LoanSavingsSystem.Ussd
    alias LoanSavingsSystem.Ussd.Ussd
    alias LoanSavingsSystem.Accounts.User
    alias LoanSavingsSystem.Companies.Staff
    alias LoanSavingsSystem.Products.Product
    alias LoanSavingsSystem.Loan.LoanProduct
    alias LoanSavingsSystem.Loan.USSDLoanProduct
    alias LoanSavingsSystem.Repo
    alias LoanSavingsSystem.Loan.Loans
    alias LoanSavingsSystem.Loan.LoanCharge
    alias LoanSavingsSystem.Loan.LoanProductCharge
    alias LoanSavingsSystem.Charges.Charge
    alias LoanSavingsSystem.Transactions.Transaction
    alias LoanSavingsSystem.Loan.LoanChargePayment
    alias LoanSavingsSystem.Loan.LoanRepaymentSchedule
    alias LoanSavingsSystem.Ussd.UssdRequest
	alias LoanSavingsSystem.Notifications.Sms
	alias LoanSavingsSystem.Emails.Email
	alias LoanSavingsSystem.UssdLogs.UssdLog
    require Record
    require Logger
    import Ecto.Query, warn: false
	import SweetXml
	import RSA


    def index(conn, _params) do
        render(conn, "index.html")
    end



	def handlePaymentConfirmation(conn, _params) do
		IO.inspect _params
		transactionId = _params["transaction"]["id"];
		status_code = _params["transaction"]["status_code"];
		airtelRefNo = _params["transaction"]["airtel_money_id"];
		IO.inspect transactionId
		
		
		if(status_code=="TS") do
			#status = "Pending";
			status = "Success";
			query = from au in LoanSavingsSystem.Transactions.Transaction,
				where: (au.orderRef == type(^transactionId, :string) and au.status == type(^status, :string)),
				select: au
			transaction = Repo.one(query);
			
			if(transaction) do
				attrs = %{status: "Success", referenceNo: airtelRefNo}
				transaction
				|> LoanSavingsSystem.Transactions.Transaction.changesetForUpdate(attrs)
				|> Repo.update()
				
				#status = "PENDING";
				status = "SUCCESSFUL";
				query = from au in LoanSavingsSystem.FixedDeposit.FixedDepositTransaction,
					where: (au.transactionId == type(^transaction.id, :integer) and au.status == type(^status, :string)),
					select: au
				fixedDepositTransaction = Repo.one(query);
				
				if(fixedDepositTransaction) do
					attrs = %{status: "SUCCESSFUL"}
					fixedDepositTransaction
					|> LoanSavingsSystem.FixedDeposit.FixedDepositTransaction.changesetForUpdate(attrs)
					|> Repo.update()
					
					
					#fixedDepositStatus = "PENDING";
					fixedDepositStatus = "ACTIVE";
					query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
						where: (au.id == type(^fixedDepositTransaction.fixedDepositId, :integer) and au.fixedDepositStatus == type(^fixedDepositStatus, :string)),
						select: au
					fixedDeposit = Repo.one(query);
					
					if(fixedDeposit) do
						attrs = %{fixedDepositStatus: "ACTIVE"}
						fixedDeposit
						|> LoanSavingsSystem.FixedDeposit.FixedDeposits.changesetForUpdate(attrs)
						|> Repo.update()
						
						
						query = from au in LoanSavingsSystem.Accounts.Account,
							where: (au.userId == type(^fixedDeposit.userId, :integer)),
							select: au
						acc = Repo.one(query);

						acct = LoanSavingsSystem.Accounts.Account.changesetForUpdate(acc,
						%{
							accountNo: acc.accountNo,
							accountType: acc.accountType,
							accountVersion: acc.accountVersion,
							clientId: acc.clientId,
							currencyDecimals: acc.currencyDecimals,
							currencyId: acc.currencyId,
							currencyName: acc.currencyName,
							status: acc.status,
							totalCharges: acc.totalCharges,
							totalDeposits: (acc.totalDeposits + fixedDeposit.principalAmount),
							totalInterestEarned: acc.totalInterestEarned,
							totalInterestPosted: acc.totalInterestPosted,
							totalPenalties: acc.totalPenalties,
							totalTax: acc.totalTax,
							totalWithdrawals: acc.totalWithdrawals,
							userId: acc.userId,
							userRoleId: acc.userRoleId,
							DateClosed: nil,
							accountOfficerUserId: acc.accountOfficerId,
							blockedByUserId: acc.blockedByUserId,
							blockedReason: acc.blockedReason,
							deactivatedReason: acc.deactivatedReason,
							derivedAccountBalance: acc.derivedAccountBalance,
							externalId: acc.externalId
						})

						Repo.update!(acct)
					end
				end
			end
		end
		
		response = "OK"
		send_response(conn, response)
	end



	def logUssdRequest(userId, action, parentRoute, status, mobileNo, details) do
	
		ussd_log = %UssdLog{
		  userId: userId,
		  action: action,
		  parentRoute: parentRoute,
		  status: status,
		  details: details,
		  mobileNo: mobileNo
		}
		
		IO.inspect ("ussd_log");
		IO.inspect (ussd_log);

		case Repo.insert(ussd_log) do
			{:ok, ussd_log} ->
				nil
			{:error, changeset} ->
				Logger.info("Fail")
				nil;
		end
	end
						
    def initiateUssd(conn, dd) do
        {:ok, body, _conn} = Plug.Conn.read_body(conn)


        Logger.info  "-----------"
        Logger.info  "Debug USSD Controller Starts here"
        Logger.info  body

        query_params = conn.query_params;
        session_id = query_params["SESSION_ID"];
        query_params = conn.query_params;
        Logger.info  Jason.encode!(query_params)
        mobile_number = query_params["MOBILE_NUMBER"]
        text = query_params["USSD_BODY"]

        cmd = query_params["SERVICE_KEY"]
        orginal_short_code = cmd
        Logger.info cmd

        cmd = if (String.equivalent?(cmd, "254*540")) do

            Logger.info "temporary ussd code"
            cmd = "*778#";
            cmd
        else
            text
        end


        query = from cl in LoanSavingsSystem.SystemSetting.ClientTelco, where: (cl.ussdShortCode== ^cmd), select: cl
            clientTelco = Repo.one(query);

        query = from au in UssdRequest, where: au.mobile_number == ^mobile_number and au.session_id == ^session_id, select: au
        ussdRequests = Repo.all(query);

        text = if (Enum.count(ussdRequests) == 0) do

            text = text <> "*";

            Logger.info  "No Ussd Requests"
            Logger.info  text

            ussdRequest = %UssdRequest{}
            ussdRequest = %UssdRequest{mobile_number: mobile_number, request_data: text, session_id: session_id, session_ended: 0}
            case Repo.insert(ussdRequest) do
                {:ok, ussdRequest} ->
                    query = from au in UssdRequest, where: au.mobile_number == ^mobile_number and au.session_id == ^session_id, select: au
                    ussdRequest = Repo.one(query);
                    ussdRequest.request_data
                {:error, changeset} ->
                    Logger.info("Fail")
                    nil;
            end
        else

            Logger.info  "Ussd Requests Exist"

            Logger.info  text

            text = String.trim_leading(text, "*");
            ussdRequest = Enum.at(ussdRequests, 0);

            Logger.info ussdRequest.request_data
			reqdat = ussdRequest.request_data;

            reqdat = String.trim_trailing(reqdat, " ")

            text = reqdat <> text <> "*";

            text = String.replace(text, "*B*", "*b*")
            Logger.info  text


            attrs = %{request_data: text}

            ussdRequest
            |> UssdRequest.changesetForUpdate(attrs)
            |> Repo.update()

            text
        end
		
		
		Logger.info "Text===========>";
        Logger.info text;


        if(is_nil(text)) do
            #response = %{
            #    Message: "Technical issues experienced. Press\n\nb. Back\n",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA2"
            #}

			response = "Technical issues experienced. Press\n\nb. Back\n"
            send_response(conn, response)
        else
			clientId = clientTelco.clientId
            Logger.info clientId;
            query = from cl in LoanSavingsSystem.Client.Clients, where: cl.id == ^clientId, select: cl
                client = Repo.one(query);
                clientName = client.clientName
                Logger.info Jason.encode!(client.id)


            query = from au in LoanSavingsSystem.Accounts.User, where: au.username == ^mobile_number, select: au
            appusers = Repo.all(query)
            Logger.info  Enum.count(appusers)



            Logger.info  "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
            tempText = text;
            Logger.info tempText
            text = if String.ends_with?(tempText, "*b*") do
                tempText = "*788#*";

            else
                b_located = String.contains?(tempText, "*b*")
                text = if b_located == true do

                    tempCheckMenu = String.split(tempText, "*b*")
                    Logger.info tempCheckMenu
                    tempCheckMenuFirst = Enum.at(tempCheckMenu, 0);
                    Logger.info tempCheckMenuFirst
                    tempCheckMenuLength = Enum.count(tempCheckMenu);
                    Logger.info tempCheckMenuLength

                    text = if Enum.count(tempCheckMenu) > 1 do
                        Logger.info "tempCheckMenuLast"
                        tempCheckMenuLast = Enum.at(tempCheckMenu, tempCheckMenuLength-1);
                        Logger.info tempCheckMenuLast
                        text = if String.length(tempCheckMenuLast) > 0 do
                              strlen_ = String.length(tempCheckMenuLast) - 1;
                              tempCheckMenuLast = String.slice(tempCheckMenuLast, 0, strlen_);
                              tempText = "*788#*#{tempCheckMenuLast}*"
                        else
                            text

                        end
                    end
                else
                  b_located = String.contains?(tempText, "*0*")
                  text = if b_located == true do

                      text = false
                  else
                      text

                  end


                end
            end


            Logger.info("!!!!!!!")
            Logger.info(text);
			
			
			if(text) do
				if (Enum.count(appusers)>0) do
					Logger.info("==2222=================")
					
					
			
			
					Logger.info Jason.encode!(client.id)
					Logger.info text
					query = from au in UssdRequest, where: au.mobile_number == ^mobile_number and au.session_id == ^session_id, select: au
					ussdRequests = Repo.all(query);
					ussdRequest = Enum.at(ussdRequests, 0);
					Logger.info (Enum.count(ussdRequests));

					if(ussdRequest.is_logged_in != 1) do
						#request_user_password(conn, mobile_number, cmd, text, ussdRequests, "Welcome to MFZ Zipake Savings\n\nPlease enter your 4 digit Pin", client, clientTelco);
						appUser = Enum.at(appusers, 0);
						logUssdRequest(appUser.id, "INITIATE USSD", nil, "SUCCESS", mobile_number, "Access MFZ Zipake USSD");
						loginOrRecover(conn, mobile_number, cmd, text, ussdRequests, "Welcome to MFZ Zipake Savings\n\nPress\n1. Login\n2. I Forgot My Pin", client, clientTelco);
					else
						welcome_menu(conn, mobile_number, cmd, text, client, clientTelco)
					end
				else
					Logger.info(cmd)
					Logger.info(mobile_number)


					Logger.info("short_code...")
					Logger.info(cmd)
					Logger.info("text...")
					Logger.info(text)
					
					if text do
						if(text == "254*") do
                            #response = %{
                            #    Message: "Welcome to #{clientName}. \n\nType your first name",
                            #    ClientState: 1,
                            #    Type: "Response",
                            #    key: "CON"
                            #}


							response = "Welcome to #{clientName}. \n\nType your first name"
                            send_response(conn, response)
                        else
							checkMenu = String.split(text, "*")
                            checkMenuLength = Enum.count(checkMenu)
                            Logger.info(checkMenuLength)

                            case checkMenuLength do
                                3 ->
                                    #response = %{
                                    #    Message: "Welcome to #{clientName}. \n\nType your first name",
                                    #    ClientState: 1,
                                    #    Type: "Response",
                                    #    key: "CON"
                                    #}

									response = "Welcome to #{clientName}. \n\nType your NRC Number"
                                    send_response(conn, response)
                                4 ->
								
									nrc = Enum.at(checkMenu, 2)
                                    checkAlpha = Regex.match?(~r/([0-9][0-9][0-9][0-9][0-9][0-9])\/([0-9][0-9])\/([0-9])/, nrc)


                                    case checkAlpha do
                                        true ->
                                            #response = %{
                                            #    Message: "Enter a 4-Digit security pin",
                                            #    ClientState: 1,
                                            #    Type: "Response",
                                            #    key: "CON"
                                            #}
											meansOfIdentificationType = "NRC";
											
											IO.inspect ">>>>>>>>>>>>>>>>>>>>>>";
											user = Enum.at(appusers, 0);
											IO.inspect user
											query = from au in LoanSavingsSystem.Client.UserBioData, where: au.meansOfIdentificationNumber == ^nrc and au.meansOfIdentificationType == ^meansOfIdentificationType, select: au
                                                userBioData = Repo.one(query);
												
											if (is_nil(userBioData)) do
												activeStatus = "ACTIVE"
												query = from au in LoanSavingsSystem.Accounts.SecurityQuestions, where: au.status == ^activeStatus, select: au
													sq = Repo.all(query);
													
												securityQuestions = [];
												securityQuestions = for {k, v} <- Enum.with_index(sq) do
													#Logger.info (k.id)
													
													question = k.question
													qn = "#{v+1}. " <> question
													securityQuestions = securityQuestions ++ [qn]
													Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
													securityQuestions
													
												end


												if (Enum.count(securityQuestions)>0) do
													optionsList = "";
													optionsList = Enum.join(securityQuestions, "\n");

													Logger.info optionsList
													msg = "Choose a security question to answer. \n\n" <> optionsList <> "\nb. Back"

													#response = %{
													#    Message: msg,
													#    ClientState: 2,
													#    Type: "Response",
													#    key: "CON"
													#}
													response = msg
													send_response(conn, response)
												else
													#response = %{
													#    Message: "Deposit Period\n\n1. Choose One\n2. Exit\nb. Back",
													#    ClientState: 2,
													#    Type: "Response",
													#    key: "CON"
													#}
													response = "Choose One\n0. Exit\nb. Back"
													send_response(conn, response)

												end
											else
												IO.inspect checkMenu
												checkMenuSize = Enum.count(checkMenu) - 3;
												checkMenuUpd = Enum.slice(checkMenu, 0..checkMenuSize)
												IO.inspect checkMenuUpd
												IO.inspect checkMenuSize
												#IO.inspect Enum.join(checkMenuUpd, "*");

												text = Enum.join(checkMenuUpd, "*");
												IO.inspect text
												text = text <> "*";
												IO.inspect text
												attrs = %{request_data: text}
												IO.inspect attrs

												ussdRequest = Enum.at(ussdRequests, 0);

												query = from au in UssdRequest, where: au.id == ^ussdRequest.id, select: au
													ussdRequest = Repo.one(query);
												IO.inspect ussdRequest
												
												ussdRequest
												|> UssdRequest.changesetForUpdate(attrs)
												|> Repo.update()
												
												response = "NRC provided has already registered for this service. \nEnter your valid NRC Number again. Press \n\nb. Back\n0. Log Out"
												send_response(conn, response)

											end
                                        false ->
                                            checkMenuSize = Enum.count(checkMenu) - 3;
                                            checkMenuUpd = Enum.slice(checkMenu, 0..checkMenuSize)
                                            IO.inspect checkMenuUpd
                                            IO.inspect checkMenuSize

                                            text = Enum.join(checkMenuUpd, "*");
                                            IO.inspect text
                                            text = text <> "*";
                                            IO.inspect text
                                            attrs = %{request_data: text}
                                            IO.inspect attrs

                                            ussdRequest = Enum.at(ussdRequests, 0);

                                            query = from au in UssdRequest, where: au.id == ^ussdRequest.id, select: au
                                                ussdRequest = Repo.one(query);
                                            IO.inspect ussdRequest
                                            ussdRequest
                                            |> UssdRequest.changesetForUpdate(attrs)
                                            |> Repo.update()


                                            #response = %{
                                            #    Message: "Invalid NRC provided. Enter your NRC Number",
                                            #    ClientState: 1,
                                            #    Type: "Response",
                                            #    key: "CON"
                                            #}


											response = "Invalid NRC provided. Enter your NRC Number"
                                            send_response(conn, response)

                                    end

                                5 ->

                                    sqSelected = Enum.at(checkMenu, 3)
									IO.inspect "selected security question"
									IO.inspect sqSelected
									activeStatus = "ACTIVE"
									query = from au in LoanSavingsSystem.Accounts.SecurityQuestions, where: au.status == ^activeStatus, select: au
										sq = Repo.all(query);
										
									securityQuestions = [];
									securityQuestions = for {k, v} <- Enum.with_index(sq) do
										#Logger.info (k.id)
										question = k.question
										securityQuestions = securityQuestions ++ [question]
										Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
										securityQuestions
										
									end


									sqSelected = elem Integer.parse(sqSelected), 0
									sqSelected = Enum.at(securityQuestions, (sqSelected - 1));
									sqSelected = Enum.join(sqSelected, "\n");

									
									msg = "Remember your selected question and answer provided\n\n" <> sqSelected <> "" <> "\nb. Back"

									#response = %{
									#    Message: msg,
									#    ClientState: 2,
									#    Type: "Response",
									#    key: "CON"
									#}
									response = msg
									send_response(conn, response)
									
									

                                6 ->
                                    sqAnsSelected = Enum.at(checkMenu, 4)
									sqAnsSelected = String.trim(sqAnsSelected);
									
									if (String.length(sqAnsSelected)>2) do
										response = "Enter a 4-Digit security pin"
										send_response(conn, response)
									else
										checkMenuSize = Enum.count(checkMenu) - 3;
										checkMenuUpd = Enum.slice(checkMenu, 0..checkMenuSize)
										IO.inspect checkMenuUpd
										IO.inspect checkMenuSize

										text = Enum.join(checkMenuUpd, "*");
										IO.inspect text
										text = text <> "*";
										IO.inspect text
										attrs = %{request_data: text}
										IO.inspect attrs

										ussdRequest = Enum.at(ussdRequests, 0);

										query = from au in UssdRequest, where: au.id == ^ussdRequest.id, select: au
											ussdRequest = Repo.one(query);
										IO.inspect ussdRequest
										ussdRequest
										|> UssdRequest.changesetForUpdate(attrs)
										|> Repo.update()


										#response = %{
										#    Message: "Invalid NRC provided. Enter your NRC Number",
										#    ClientState: 1,
										#    Type: "Response",
										#    key: "CON"
										#}


										response = "Invalid answer provided. Your answer must be more than two characters long.\n Please enter a valid answer\n\nb. Back"
										send_response(conn, response)

									end

                                7 ->
									pin = Enum.at(checkMenu, 5)
                                    IO.inspect "pin..." <> pin
                                    checkDigits = Regex.match?(~r/^([0-9]{4})+$/, pin)

                                    case checkDigits do
                                        true ->
                                            #response = %{
                                            #    Message: "Retype the 4-Digit security pin again",
                                            #    ClientState: 1,
                                            #    Type: "Response",
                                            #    key: "CON"
                                            #}

											response = "Retype the 4-Digit security pin again"
                                            send_response(conn, response)
                                        false ->
                                            IO.inspect "checkMenu"
                                            IO.inspect checkMenu
                                            checkMenuSize = Enum.count(checkMenu) - 3;
                                            checkMenuUpd = Enum.slice(checkMenu, 0..checkMenuSize)
                                            IO.inspect checkMenuUpd
                                            IO.inspect checkMenuSize
                                            #IO.inspect Enum.join(checkMenuUpd, "*");

                                            text = Enum.join(checkMenuUpd, "*");
                                            IO.inspect text
                                            text = text <> "*";
                                            IO.inspect text
                                            attrs = %{request_data: text}
                                            IO.inspect attrs

                                            ussdRequest = Enum.at(ussdRequests, 0);

                                            query = from au in UssdRequest, where: au.id == ^ussdRequest.id, select: au
                                                ussdRequest = Repo.one(query);
                                            IO.inspect ussdRequest
                                            #ussdRequest = Ecto.Changeset.change ussdRequest, request_data: text
                                            #case Repo.update ussdRequest do
                                            #	{:ok, struct} ->
                                            #		IO.inspect ""
                                            #		IO.inspect struct
                                            #		Repo.transaction()

                                            #	{:error, changeset} ->
                                            #		IO.inspect changeset
                                            #end
                                            #UssdRequest.changesetForUpdate(ussdRequest, attrs)
                                            #|> prepare_update(conn, ussdRequest)
                                            #|> Repo.transaction()
                                            ussdRequest
                                            |> UssdRequest.changesetForUpdate(attrs)
                                            |> Repo.update()


                                            #response = %{
                                            #    Message: "Incorrect values provided. Please enter a valid 4-digit security pin",
                                            #    ClientState: 1,
                                            #    Type: "Response",
                                            #    key: "CON"
                                            #}

											response = "Incorrect values provided. Please enter a valid 4-digit security pin"
                                            send_response(conn, response)

                                    end
								
								
								
								8 ->
									#password = Enum.at(checkMenu, 2)
                                    #cpassword = Enum.at(checkMenu, 3)

                                    pin = Enum.at(checkMenu, 5)
                                    rpin = Enum.at(checkMenu, 6)
                                    IO.inspect "pin..." <> pin
                                    IO.inspect "rpin..." <> rpin
                                    checkDigits = Regex.match?(~r/^([0-9]{4})+$/, pin)

                                    case checkDigits do
                                        false ->
                                            #response = %{
                                            #    Message: "Retype the 4-Digit security pin again",
                                            #    ClientState: 1,
                                            #    Type: "Response",
                                            #    key: "CON"
                                            #}

											response = "Retype the 4-Digit security pin again"
                                            send_response(conn, response)
                                        true ->
                                            case String.equivalent?(pin, rpin) do
                                                false ->
                                                    #response = %{
                                                    #    Message: "Pin mismatch! The pins you have provided did not match. Enter a valid 4-digit security pin",
                                                    #    ClientState: 1,
                                                    #    Type: "Response",
                                                    #    key: "CON"
                                                    #}

													response = "Pin mismatch! The pins you have provided did not match. Enter a valid 4-digit security pin"
                                                    send_response(conn, response)
                                                true ->
													mobileNumber = mobile_number;
													IO.inspect mobileNumber;
													mobileNumberTruncated = String.slice(mobileNumber, 3..11);

													xml = %{"client_id": "d3c57107-fd9a-4ea6-9aa1-461ac69384b0", "client_secret": "7ec36e58-d805-4076-9910-4a050328ce3c", "grant_type": "client_credentials"}
													IO.inspect "xml3"
													IO.inspect xml
													xml = Jason.encode!(xml);
													options = [];		
													#ssl: [{:versions, [:'tlsv3']}], recv_timeout: 5000
													header = [{"Content-Type", "application/json"}, {"Accept", "*/*"}];
													url = "https://openapiuat.airtel.africa/auth/oauth2/token";

													case HTTPoison.request(:post, url, xml, [{"Content-Type", "application/json"}, {"Accept", "*/*"}]) do
														{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
															IO.inspect "000000000000000000"
															IO.inspect reason
															logUssdRequest(nil, "NEW CLIENT", nil, "FAILED", mobileNumber, "New client profile not created successfully");
															response = "We could not create a profile for you at the moment. Please check back later"
															send_response(conn, response)
														{:ok, struct} ->
															IO.inspect struct.body
															bearerBody =  Jason.decode!(struct.body)
															IO.inspect bearerBody
															bearer = bearerBody["access_token"]
															IO.inspect bearer
															
															mobileNumberTruncated = String.slice(mobileNumber, 3..11);
															url = "https://openapiuat.airtel.africa/standard/v1/users/#{mobileNumberTruncated}";
															case HTTPoison.request(:get, url, "", [{"Accept", "*/*"}, {"X-Country", "ZM"}, {"X-Currency", "ZMW"}, {"Authorization", "Bearer #{bearer}"}]) do
																{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
																	IO.inspect "000000000000000000"
																	IO.inspect reason
																{:ok, struct} ->
																	IO.inspect struct.body
																	bodyStruct =  Jason.decode!(struct.body)
																	IO.inspect bodyStruct
																	fname = bodyStruct["data"]["first_name"]
																	IO.inspect fname
																	lname = bodyStruct["data"]["last_name"]
																	IO.inspect lname
																	nrc = Enum.at(checkMenu, 2)
																	IO.inspect nrc
																	pin = Enum.at(checkMenu, 5)
																	IO.inspect pin
																	pinEnc = LoanSavingsSystem.Accounts.User.encrypt_password(pin)
																	pinEnc = String.trim_trailing(pinEnc, " ")
																	Logger.info("fname..." <> fname)
																	Logger.info("lname..." <> lname)
																	Logger.info("nrc..." <> nrc)
																	Logger.info("pinEnc..." <> pinEnc)

																	securityQuestionAnswer = Enum.at(checkMenu, 4)
																	securityQuestionAnswer = String.trim(securityQuestionAnswer);
																	securityQuestionAnswer = String.downcase(securityQuestionAnswer);
																	IO.inspect securityQuestionAnswer
																	
																	
																	sqSelected = Enum.at(checkMenu, 3)
																	IO.inspect sqSelected
																	IO.inspect "selected security question"
																	IO.inspect sqSelected
																	activeStatus = "ACTIVE"
																	query = from au in LoanSavingsSystem.Accounts.SecurityQuestions, where: au.status == ^activeStatus, select: au
																		securityQuestions = Repo.all(query);

																	sqSelected = elem Integer.parse(sqSelected), 0
																	sqSelected = Enum.at(securityQuestions, (sqSelected - 1));
																	sqSelectedId = sqSelected.id;

																	clientId = client.id
																	appUser = %LoanSavingsSystem.Accounts.User{canOperate: true, ussdActive: 1, username: mobile_number, clientId: clientId, status: "ACTIVE", pin: pinEnc, securityQuestionId: sqSelectedId, securityQuestionAnswer: securityQuestionAnswer}
																	case Repo.insert(appUser) do
																		{:ok, appUser} ->
																			userId = appUser.id
																			firstName = fname
																			lastName = lname
																			
													
													
																			meansOfIdentificationType = "NRC"
																			meansOfIdentificationNumber = Enum.at(checkMenu, 2)

																			appUserBioData = %LoanSavingsSystem.Client.UserBioData{firstName: firstName, lastName: lastName, userId: userId, clientId: clientId,
																				mobileNumber: mobile_number, meansOfIdentificationType: meansOfIdentificationType,
																				meansOfIdentificationNumber: meansOfIdentificationNumber}
																			case Repo.insert(appUserBioData) do
																				{:ok, appUserBioData} ->
																					status = "ACTIVE"
																					roleType = "INDIVIDUAL"
																					otp = Enum.random(1_000..9_999)
																					otp = "#{otp}"
																					appUserRole = %LoanSavingsSystem.Accounts.UserRole{roleType: roleType, status: status, userId: userId, clientId: clientId, otp: otp}
																					case Repo.insert(appUserRole) do
																						{:ok, appUserRole} ->
																							accountNo = mobile_number
																							accountType = "SAVINGS"
																							accountVersion = clientTelco.accountVersion
																							clientId = client.id
																							currencyDecimals = client.defaultCurrencyDecimals
																							currencyId = client.defaultCurrencyId
																							currencyName = client.defaultCurrencyName
																							status = "ACTIVE"
																							totalCharges = 0.00;
																							totalDeposits = 0.00;
																							totalInterestEarned = 0.00;
																							totalInterestPosted = 0.00;
																							totalPenalties = 0.00;
																							totalTax = 0.00;
																							totalWithdrawals = 0.00;
																							derivedAccountBalance = 0.00;
																							userId = appUser.id;
																							userRoleId = appUserRole.id;


																							account = %LoanSavingsSystem.Accounts.Account{
																								accountNo: accountNo,
																								accountType: accountType,
																								accountVersion: accountVersion,
																								clientId: clientId,
																								currencyDecimals: currencyDecimals,
																								currencyId: currencyId,
																								currencyName: currencyName,
																								status: status,
																								totalCharges: totalCharges,
																								totalDeposits: totalDeposits,
																								totalInterestEarned: totalInterestEarned,
																								totalInterestPosted: totalInterestPosted,
																								totalPenalties: totalPenalties,
																								derivedAccountBalance: derivedAccountBalance,
																								totalTax: totalTax,
																								totalWithdrawals: totalWithdrawals,
																								userId: userId,
																								userRoleId: userRoleId,
																							}
																							case Repo.insert(account) do
																							{:ok, account} ->
																									#response = %{
																									#    Message: "Your new #{clientName} account has been setup for you. Press\n\nb. Back\n0. Log Out",
																									#    ClientState: 1,
																									#    Type: "Response",
																									#    key: "BA3"
																									#}
																									
																									logUssdRequest(appUser.id, "NEW CLIENT", nil, "SUCCESS", mobile_number, "New client profile created successfully");


																									naive_datetime = Timex.now
																									sms = %{
																										mobile: mobile_number,
																										msg: "Dear #{firstName}, Welcome to ZIPAKE. You can log in to fix a deposit at great rates.\n\nDo not share your ZIPAKE Pin with anyone",
																										status: "READY",
																										type: "SMS",
																										msg_count: "1",
																										date_sent: naive_datetime
																									}
																									Sms.changeset(%Sms{}, sms)
																									|> Repo.insert()


																									response = "Your new #{clientName} account has been setup for you. Press\n\nb. Back\n0. Log Out"
																									send_response(conn, response)






																							{:error, changeset} ->
																									Logger.info("Fail")
																									#response = %{
																									#    Message: "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out",
																									#    ClientState: 1,
																									#    Type: "Response",
																									#    key: "BA3"
																									#}
																									logUssdRequest(conn.assigns.user.id, "NEW CLIENT", nil, "FAILED", mobile_number, "New client profile creation Failed");

																									response = "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out"
																									send_response(conn, response)
																							end
																						{:error, changeset} ->
																							Logger.info("Fail")
																							#response = %{
																							#    Message: "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out",
																							#    ClientState: 1,
																							#    Type: "Response",
																							#    key: "BA3"
																							#}

																							response = "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out"
																							send_response(conn, response)
																					end
																				{:error, changeset} ->
																					Logger.info("Fail")
																					#response = %{
																					#    Message: "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out",
																					#    ClientState: 1,
																					#    Type: "Response",
																					#    key: "BA3"
																					#}

																					response = "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out"
																					send_response(conn, response)
																			end


																		{:error, changeset} ->
																			Logger.info("Fail")
																			#response = %{
																			#    Message: "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out",
																			#    ClientState: 1,
																			#    Type: "Response",
																			#    key: "BA3"
																			#}

																			response = "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out"
																			send_response(conn, response)
																	end
															end
													end
							
							
                                                    
                                            end
                                    end
                            end
						end
					
					else
						#response = %{
						#	Message: "Invalid input provided",
						#	ClientState: 1,
						#	Type: "Response",
						#	key: "BA1"
						#}
						response = "Invalid input provided"
						send_response(conn, response)
					end
				end
			else
				#response = %{
				#  Message: "Thank you and Good Bye",
				#  ClientState: 1,
				#  Type: "Response",
				#  key: "end"
				#}

				response = "Thank you and Good Bye"
				end_session(ussdRequests, conn, response);
			end
		end
	end


	def end_session(ussdRequests, conn, response) do
		query_params = conn.query_params;
        mobile_number = query_params["MOBILE_NUMBER"]
		
		query = from au in LoanSavingsSystem.Accounts.User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUser = Repo.one(query);
		
		logUssdRequest(appUser.id, "SESSION END", nil, "SUCCESS", mobile_number, "Session Ended By Client");
		attrs = %{session_ended: 1};
		if(Enum.count(ussdRequests)>0) do
			ussdRequest = Enum.at(ussdRequests, 0);

			ussdRequest
			|> UssdRequest.changesetForUpdate(attrs)
			|> Repo.update()
		end

		send_response(conn, response)
	end

	def handleMakeDepositChoice(conn, mobile_number, cmd, text, checkMenu, client, clientTelco) do
        checkMenuLength = Enum.count(checkMenu)
        defaultCurrency = client.defaultCurrencyId
        valueEntered = Enum.at(checkMenu, (checkMenuLength-2))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
        if valueEntered == "b" do
            #response = %{
            #    Message: "BA3",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA3"
            #}

			response = "BA3"
            send_response(conn, response)
        else
            case checkMenuLength do
                4 ->
                    #response = %{
                    #    Message: "Enter Amount",
                    #    ClientState: 1,
                    #    Type: "Response",
                    #    key: "CON"
                    #}
					response = "Enter Amount"
                    send_response(conn, response)
                5 ->
                    amount = Enum.at(checkMenu, 3)
					if (checkIfFloat(amount)===false) do
						response = "Invalid amount provided.\n\nb. Back\n0. Exit"
						send_response(conn, response)
					else
						Logger.info "amount #{amount}"
						query = from au in LoanSavingsSystem.Products.Product,
							where: (au.minimumPrincipal <= type(^amount, :float) and au.status == "ACTIVE" and au.maximumPrincipal >= type(^amount, :float) and au.currencyId == type(^defaultCurrency, :integer)) ,
							select: au
						savingsProducts = Repo.all(query)




						if Enum.count(savingsProducts) == 0 do
							#response = %{
							#    Message: "We do not have a fixed deposit package for the amount provided\n\nb. Back\n0. Exit",
							#    ClientState: 2,
							#    Type: "Response",
							#    key: "CON"
							#}

							query = from au in LoanSavingsSystem.Products.Product,
								where: (au.status == "ACTIVE" and au.currencyId == type(^defaultCurrency, :integer)) ,
								order_by: [desc: :minimumPrincipal, desc: :maximumPrincipal],
								select: au
							savingsProducts = Repo.all(query)

							if Enum.count(savingsProducts)>0 do
								minSavingsProduct = Enum.at(savingsProducts, 0);
								maxSavingsProduct = Enum.at(savingsProducts, (Enum.count(savingsProducts)-1));
								IO.inspect (minSavingsProduct);
								IO.inspect (maxSavingsProduct);
								#minSavingsProductMin = Float.ceil(minSavingsProduct.minimumPrincipal, minSavingsProduct.currencyDecimals)
								#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [{decimals, minSavingsProduct.currencyDecimals}])
								#minSavingsProductMin = Float.to_string(minSavingsProductMin)
								minSavingsProductMin = minSavingsProduct.minimumPrincipal;
								minSavingsProductMin = :erlang.float_to_binary((minSavingsProductMin), [{:decimals, minSavingsProduct.currencyDecimals}])
								#minSavingsProductMin = Float.to_string(minSavingsProductMin)


								#maxSavingsProductMin = Float.ceil(maxSavingsProduct.maximumPrincipal, maxSavingsProduct.currencyDecimals)
								#maxSavingsProductMin = :erlang.float_to_binary((maxSavingsProduct.maximumPrincipal), [{decimals, 3}])
								#maxSavingsProductMin = Float.to_string(maxSavingsProductMin)
								maxSavingsProductMin = maxSavingsProduct.maximumPrincipal;
								maxSavingsProductMin = :erlang.float_to_binary((maxSavingsProductMin), [{:decimals, maxSavingsProduct.currencyDecimals}])
								#maxSavingsProductMin = Float.to_string(maxSavingsProductMin)
								IO.inspect (minSavingsProductMin);
								IO.inspect (maxSavingsProductMin);
								response = "We do not have a fixed deposit package for the amount provided. You can only deposit between K" <> minSavingsProductMin <> " and K" <> maxSavingsProductMin <> "\n\nb. Back\n0. Exit"
								send_response(conn, response)
							else
								response = "We do not have a fixed deposit package for the amount provided\n\nb. Back\n0. Exit"
								send_response(conn, response)
							end


						else

							dayOptions = [];
							dayOptions = for {k, v} <- Enum.with_index(savingsProducts) do
								#Logger.info (k.id)
								totalRepayAmount =0.00
								if Enum.member?(dayOptions, k.defaultPeriod) do

								else
									default_rate = k.interest
									default_period = k.defaultPeriod
									annual_period = k.yearLengthInDays
									amt = elem Integer.parse(amount), 0


									totalRepayments = calculate_maturity_repayments(amt, default_period, default_rate, annual_period, k.interestMode, k.interestType, k.periodType)
									Logger.info "Test";
									Logger.info ((totalRepayments));
									Logger.info ((k.currencyDecimals));

									totalRepayAmount = Float.ceil(totalRepayments, k.currencyDecimals)
									totalRepayAmount = :erlang.float_to_binary((totalRepayments), [{:decimals, k.currencyDecimals}])
									#totalRepayAmount = Float.to_string(totalRepayAmount)
									Logger.info "#{totalRepayAmount}"
									default_period = :erlang.integer_to_binary(default_period)
									repay_entry = "#{v+1}. " <> default_period <> " " <> k.periodType <> " gives you " <> k.currencyName <> totalRepayAmount <> "  "
									Logger.info "#{totalRepayAmount}"
									dayOptions = dayOptions ++ [repay_entry]
									Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
									dayOptions
								end
							end


							if (Enum.count(dayOptions)>0) do
								optionsList = "";
								optionsList = Enum.join(dayOptions, "\n");

								Logger.info optionsList
								msg = "Choose One. \n\nDeposit " <> client.defaultCurrencyName <> amount <> " for:\n" <> optionsList <> "\nb. Back"

								#response = %{
								#    Message: msg,
								#    ClientState: 2,
								#    Type: "Response",
								#    key: "CON"
								#}
								response = msg
								send_response(conn, response)
							else
								#response = %{
								#    Message: "Deposit Period\n\n1. Choose One\n2. Exit\nb. Back",
								#    ClientState: 2,
								#    Type: "Response",
								#    key: "CON"
								#}
								response = "Deposit Period\n\n1. Choose One\n2. Exit\nb. Back"
								send_response(conn, response)

							end
						end
					end

                6 ->
                    Logger.info "ooooooooooooooooooooooooooooo"
                    Logger.info checkMenu
                    selectedIndex = Enum.at(checkMenu, 4)
                    Logger.info selectedIndex
					
					if (checkIfInteger(selectedIndex)===false) do
						response = "Invalid amount provided.\n\nb. Back\n0. Exit"
						send_response(conn, response)
					else
						selectedIndex = elem Integer.parse(selectedIndex), 0
						Logger.info selectedIndex
						Logger.info "<<<<<<"
						Logger.info selectedIndex
						amount = Enum.at(checkMenu, 3)
						Logger.info amount
						query = from au in LoanSavingsSystem.Products.Product,
							where: (au.minimumPrincipal <= type(^amount, :float) and au.status == "ACTIVE" and au.maximumPrincipal >= type(^amount, :float) and au.currencyId == type(^defaultCurrency, :integer)) ,
							select: au
						savingsProducts = Repo.all(query)
						Logger.info "savingsProducts"
						Logger.info Enum.count(savingsProducts)
						
						if (Enum.count(savingsProducts)==0 || selectedIndex>Enum.count(savingsProducts)) do
							response = "Invalid entry selected.\n\nb. Back\n0. Exit"
							send_response(conn, response)
						else

							savingsProduct = Enum.at(savingsProducts, (selectedIndex - 1));

							default_rate = savingsProduct.interest
							default_period = savingsProduct.defaultPeriod
							annual_period = savingsProduct.yearLengthInDays
							amt = elem Integer.parse(amount), 0


							totalRepayments = calculate_maturity_repayments(amt, default_period, default_rate, annual_period, savingsProduct.interestMode, savingsProduct.interestType, savingsProduct.periodType)
							Logger.info "Test";
							Logger.info ((totalRepayments));

							#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [decimals= savingsProduct.currencyDecimals])
							totalRepayAmount = Float.ceil(totalRepayments, savingsProduct.currencyDecimals)
							totalRepayAmount = :erlang.float_to_binary((totalRepayments), [{:decimals, savingsProduct.currencyDecimals}])
							#totalRepayAmount = Float.to_string(totalRepayAmount)
							Logger.info "#{totalRepayAmount}"
							default_period = :erlang.integer_to_binary(default_period)
							repay_entry = default_period <> " " <> savingsProduct.periodType <> " gives you " <> savingsProduct.currencyName <> totalRepayAmount <> "  "
							Logger.info "#{totalRepayAmount}"
							dayOptions = [];
							dayOptions = dayOptions ++ [repay_entry]
							Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"

							if (Enum.count(dayOptions)>0) do
								optionsList = "";
								optionsList = Enum.join(dayOptions, "\n");

								Logger.info optionsList
								msg = "Your preferred choice:\n" <> optionsList <> "\n\n1. Confirm\nb. Back"

								#response = %{
								#    Message: msg,
								#    ClientState: 2,
								#    Type: "Response",
								#    key: "CON"
								#}


								response = msg
								send_response(conn, response)
							else
								#response = %{
								#    Message: "Deposit Period\n\n1. Choose One\n2. Exit\nb. Back",
								#    ClientState: 2,
								#    Type: "Response",
								#    key: "CON"
								#}

								response = "Deposit Period\n\n1. Choose One\n2. Exit\nb. Back"
								send_response(conn, response)

							end
						end
					end
                7 ->
                    Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
                    selectedIndex = Enum.at(checkMenu, 4)
                    Logger.info "selectedIndex..."
                    Logger.info selectedIndex
                    selectedIndex = elem Integer.parse(selectedIndex), 0
                    Logger.info selectedIndex
                    confirmChoice = Enum.at(checkMenu, 5)
                    Logger.info confirmChoice
					
					
					if (checkIfInteger(confirmChoice)===false) do
						response = "Invalid entry. Please enter valid choice.\n\nb. Back\n0. Exit"
						send_response(conn, response)
					else
					
					
						confirmChoice = elem Integer.parse(confirmChoice), 0
						Logger.info confirmChoice
						amount = Enum.at(checkMenu, 3)
						Logger.info amount
						amount = elem Float.parse(amount), 0
						Logger.info amount
						query = from au in LoanSavingsSystem.Products.Product,
							where: (au.minimumPrincipal <= type(^amount, :float) and au.status == "ACTIVE" and au.maximumPrincipal >= type(^amount, :float) and au.currencyId == type(^defaultCurrency, :integer)) ,
							select: au
						savingsProducts = Repo.all(query)
						if (confirmChoice != 0 && confirmChoice==1) do
							#Logger.info amount

							savingsProduct = Enum.at(savingsProducts, (selectedIndex-1));

							default_rate = savingsProduct.interest
							default_period = savingsProduct.defaultPeriod
							annual_period = savingsProduct.yearLengthInDays
							#amt = elem Integer.parse(amount), 0
							amt = amount


							totalRepayments = calculate_maturity_repayments(amt, default_period, default_rate, annual_period, savingsProduct.interestMode, savingsProduct.interestType, savingsProduct.periodType)
							Logger.info "Test";
							Logger.info ((totalRepayments));

							#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [decimals= savingsProduct.currencyDecimals])
							totalRepayAmount = Float.ceil(totalRepayments, savingsProduct.currencyDecimals)
							#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [{decimals, savingsProduct.currencyDecimals}])
							totalRepayAmount = Float.to_string(totalRepayAmount)
							Logger.info "#{totalRepayAmount}"
							default_period = :erlang.integer_to_binary(default_period)
							repay_entry = default_period <> " " <> savingsProduct.periodType <> " gives you " <> savingsProduct.currencyName <> totalRepayAmount <> "  "
							Logger.info "#{totalRepayAmount}"
							Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"

							query = from au in LoanSavingsSystem.Accounts.User,
								where: (au.username == type(^mobile_number, :string)),
								select: au
							appUsers = Repo.all(query);
							appUser = Enum.at(appUsers, 0);

							individualRoleType = "INDIVIDUAL"
							query = from au in LoanSavingsSystem.Accounts.UserRole,
								where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
								select: au
							appUserRoles = Repo.all(query);
							appUserRole = Enum.at(appUserRoles, 0);

							Logger.info "Twst ........";
							Logger.info savingsProduct.id;
							Logger.info "{confirmChoice}";
							totalCharges = 0.00;

							query = from au in LoanSavingsSystem.Products.ProductCharge,
								where: (au.productId == type(^savingsProduct.id, :integer) and au.chargeWhen == "AT DEPOSIT"),
								select: au
							productCharges = Repo.all(query);
							Logger.info "Saving Charges";
							Logger.info savingsProduct.id
							Logger.info Enum.count(productCharges);

							totalCharge = 0.00;

							totalCharge = if Enum.count(productCharges) > 0 do
								totalCharge = for x <- 0..(Enum.count(productCharges)-1) do
									productCharge = Enum.at(productCharges, x);
									chargeId = productCharge.chargeId
									Logger.info "%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
									Logger.info chargeId
									query = from au in LoanSavingsSystem.Charges.Charge,
										where: (au.id == ^chargeId),
										select: au
									charges = Repo.all(query);
									charge = Enum.at(charges, 0);


									totalCharge = case charge.chargeType do
										"FLAT" ->
											totalCharge = totalCharge + charge.chargeAmount
											totalCharge
										"PERCENTAGE" ->
											totalCharge = totalCharge + (charge.chargeAmount*amount/100)
											Logger.info "charge...#{charge.chargeAmount}"
											Logger.info "amount...#{amount}"
											Logger.info "totalCharge...#{totalCharge}"
											totalCharge
									end

								end
							end

							totalCharge = if is_nil(totalCharge) do
								totalCharge = 0.00
							else
								totalCharge = Float.ceil(Enum.sum(totalCharge), savingsProduct.currencyDecimals)
							end


							query = from au in LoanSavingsSystem.Accounts.Account,
								where: (au.userRoleId == type(^appUserRole.id, :integer)),
								select: au
							accounts = Repo.all(query);
							account = Enum.at(accounts, 0);
							accountId = account.id

							accruedInterest= 0.00
							clientId= client.id
							currency= savingsProduct.currencyName
							currencyDecimals= savingsProduct.currencyDecimals
							currencyId= savingsProduct.currencyId

									Logger.info "%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
									Logger.info savingsProduct.defaultPeriod

							endDate = case savingsProduct.periodType do
								"Days" ->
									endDate = DateTime.add(DateTime.utc_now, (24*60*60*savingsProduct.defaultPeriod), :second) |> DateTime.truncate(:second)
									endDate
								"Months" ->
									endDate = DateTime.add(DateTime.utc_now, (24*60*60*savingsProduct.defaultPeriod*30), :second) |> DateTime.truncate(:second)
									endDate
								"Years" ->
									endDate = DateTime.add(DateTime.utc_now, (24*60*60*savingsProduct.defaultPeriod*savingsProduct.yearLengthInDays), :second) |> DateTime.truncate(:second)
									endDate
							end


							expectedInterest= Float.ceil((totalRepayments - amount), savingsProduct.currencyDecimals)
							fixedPeriod= savingsProduct.defaultPeriod
							fixedPeriodType= savingsProduct.periodType
							interestRate= savingsProduct.interest
							interestRateType= savingsProduct.interestType
							productInterestMode= savingsProduct.interestMode
							isDivested= false
							isMatured= false
							principalAmount= amount
							productId= savingsProduct.id
							startDate= DateTime.utc_now |> DateTime.truncate(:second)
							totalAmountPaidOut= 0.00
							totalDepositCharge= totalCharge
							totalPenalties= 0.00
							totalWithdrawalCharge= 0.00
							userId= appUser.id
							userRoleId= appUserRole.id
							yearLengthInDays= savingsProduct.yearLengthInDays
							fixedDepositStatus = "PENDING";
							userId= appUser.id
							query = from au in LoanSavingsSystem.Client.UserBioData,
								where: (au.userId == type(^userId, :integer)),
								select: au
							userBioData = Repo.one(query);

							fixedDeposit = %LoanSavingsSystem.FixedDeposit.FixedDeposits{
								accountId: accountId,
								accruedInterest: accruedInterest,
								clientId: clientId,
								currency: currency,
								currencyDecimals: currencyDecimals,
								currencyId: currencyDecimals,
								endDate: endDate,
								expectedInterest: expectedInterest,
								fixedPeriod: fixedPeriod,
								fixedPeriodType: fixedPeriodType,
								interestRate: interestRate,
								interestRateType: interestRateType,
								isDivested: isDivested,
								isMatured: isMatured,
								principalAmount: principalAmount,
								productId: productId,
								startDate: startDate,
								totalAmountPaidOut: totalAmountPaidOut,
								totalDepositCharge: totalDepositCharge,
								totalPenalties: totalPenalties,
								totalWithdrawalCharge: totalWithdrawalCharge,
								userId: userId,
								userRoleId: userRoleId,
								yearLengthInDays: yearLengthInDays,
								productInterestMode: productInterestMode,
								fixedDepositStatus: fixedDepositStatus,
								customerName: "#{userBioData.firstName} #{userBioData.lastName}"
							}
							fixedDeposit = Repo.insert!(fixedDeposit);


							Logger.info(Enum.count(productCharges))
							if Enum.count(productCharges) > 0 do
								for x <- 0..(Enum.count(productCharges)-1) do
									productCharge = Enum.at(productCharges, x);
									#chargeAmount = if(charge.chargeType=="FLAT") do
									#    chargeAmount = charge
									#    chargeAmount
									#else if(charge.chargeType=="PERCENTAGE") do
									#    chargeAmount =(charge.chargeAmount*amount/100)
									#    chargeAmount
									#end

									query = from au in Charge,
										where: (au.id == ^productCharge.chargeId),
										select: au
									charges = Repo.all(query);
									charge = Enum.at(charges, 0);
									Logger.info(charge.id)
									Logger.info(charge.chargeType)

									chargeAmount = case charge.chargeType do
										"FLAT"->
											chargeAmount = Float.ceil((charge.chargeAmount), savingsProduct.currencyDecimals)
											chargeAmount
										"PERCENTAGE"->
											chargeAmount =Float.ceil((charge.chargeAmount*amount/100), savingsProduct.currencyDecimals)
											chargeAmount
									end

									accountCharge = %LoanSavingsSystem.Charges.AccountCharge{
										accountId: accountId,
										chargeId: productCharge.chargeId,
										amountCharged: chargeAmount,
										isPaid: true,
										dateCharged: Date.utc_today,
										datePaid: Date.utc_today,
										balance: 0.00,
										userId: userId
									}


									Repo.insert(accountCharge);
								end
							end

							carriedOutByUserId= userId
							carriedOutByUserRoleId= userRoleId
							isReversed= false
							orderRef= Integer.to_string(Enum.random(1_000000000..9_999999999))
							orderRef = "ZIPAKE#{orderRef}";
							productId= savingsProduct.id
							productType= "SAVINGS"
							referenceNo= Integer.to_string(Enum.random(1_000000000..9_999999999))
							requestData= nil
							responseData= nil
							status= "Pending"
							totalAmount= amount
							transactionType= "CR"
							productCurrency= savingsProduct.currencyName


							currentBalance = calculateCurrentBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
							transactionDetail = "Deposit Payment for Fixed Deposit";
							transaction = %LoanSavingsSystem.Transactions.Transaction{
								accountId: accountId,
								carriedOutByUserId: carriedOutByUserId,
								carriedOutByUserRoleId: carriedOutByUserRoleId,
								isReversed: isReversed,
								orderRef: orderRef,
								productId: productId,
								productType: productType,
								referenceNo: referenceNo,
								requestData: requestData,
								responseData: responseData,
								status: status,
								totalAmount: totalAmount,
								transactionType: transactionType,
								userId: userId,
								userRoleId: userRoleId,
								transactionDetail: transactionDetail,
								transactionTypeEnum: "Deposit",
								newTotalBalance: (currentBalance),
								customerName: "#{userBioData.firstName} #{userBioData.lastName}",
								currencyDecimals: savingsProduct.currencyDecimals,
								currency: savingsProduct.currencyName
							};
							transaction = Repo.insert!(transaction);



							fixedDepositTransaction = %LoanSavingsSystem.FixedDeposit.FixedDepositTransaction{
								clientId: client.id,
								fixedDepositId: fixedDeposit.id,
								amountDeposited: principalAmount,
								transactionId: transaction.id,
								userId: userId,
								userRoleId: userRoleId,
								status: "PENDING"
							};
							fixedDepositTransaction = Repo.insert!(fixedDepositTransaction);


							#query = from au in LoanSavingsSystem.Accounts.Account,
							#	where: (au.userId == type(^userId, :integer) and au.userRoleId == type(^userRoleId, :integer)),
							#	select: au
							#userAccounts = Repo.all(query);
							#acc = Enum.at(userAccounts, 0);
							


							tempTotalAmount = Float.ceil(totalAmount, savingsProduct.currencyDecimals)
							tempTotalAmount = :erlang.float_to_binary((tempTotalAmount), [{:decimals, savingsProduct.currencyDecimals}])
							#tempTotalAmount = Float.to_string(tempTotalAmount)


							exInt = Float.ceil(fixedDeposit.expectedInterest, savingsProduct.currencyDecimals)
							exInt = :erlang.float_to_binary((exInt), [{:decimals, savingsProduct.currencyDecimals}])


							
							firstName = userBioData.firstName;
							
							logUssdRequest(userBioData.userId, "FIXED DEPOSIT", nil, "SUCCESS", mobile_number, "Fixed deposit saved prior to confirmation");


							naive_datetime = Timex.now
							sms = %{
								mobile: appUser.username,
								msg: "Dear #{firstName},\nYour deposit of #{productCurrency}" <> tempTotalAmount <> " has been recorded successfully. On confirmation, your deposit will be fixed for a period of #{fixedDeposit.fixedPeriod} #{fixedDeposit.fixedPeriodType} yielding you an interest of #{productCurrency}" <> exInt <> "\nOrder Ref: #{orderRef}",
								status: "READY",
								type: "SMS",
								msg_count: "1",
								date_sent: naive_datetime
							}
							Sms.changeset(%Sms{}, sms)
							|> Repo.insert()


							response = "Your fixed deposit of #{productCurrency}" <> tempTotalAmount <> " was successful. You will earn #{productCurrency}" <> exInt <> " after #{fixedDeposit.fixedPeriod} #{fixedDeposit.fixedPeriodType}. \n\nPress\nb. Back\n0. Log Out"

							send_response_with_header(conn, response)
							#timer.sleep(2*1000);


							mobileNumber = appUser.username;
							IO.inspect mobileNumber;
							mobileNumberTruncated = String.slice(mobileNumber, 3..11);

							url = "https://openapiuat.airtel.africa/auth/oauth2/token";
							amtToPay = fixedDepositTransaction.amountDeposited;
							amtToPay = Float.ceil(amtToPay, fixedDeposit.currencyDecimals)
							amtToPay = :erlang.float_to_binary((amtToPay), [{:decimals, savingsProduct.currencyDecimals}])
							#xml = "<COMMAND><TYPE>PUSHNOTI</TYPE><interfaceId>09375</interfaceId><MSISDN>#{mobileNumberTruncated}</MSISDN><MSISDN2>889001203</MSISDN2><AMOUNT>#{amtToPay}</AMOUNT><BILLERID>889065746</BILLERID><MEMO>Betpawa Deposit</MEMO><MERCHANT_TXN_ID>#{fixedDepositTransaction.id}</MERCHANT_TXN_ID><USERNAME>BETLION</USERNAME><PASSWORD>BET_AUTH</PASSWORD><REFERENCE_NO>#{fixedDepositTransaction.id}</REFERENCE_NO><MESSAGE>Enter Pin To Make Payment</MESSAGE></COMMAND>";
							xml = "<COMMAND><TYPE>PUSHNOTI</TYPE><interfaceId>09375</interfaceId><MSISDN>#{mobileNumberTruncated}</MSISDN><MSISDN2>889001203</MSISDN2><AMOUNT>#{amtToPay}</AMOUNT><BILLERID>889065746</BILLERID><MEMO>Betpawa Deposit</MEMO><MERCHANT_TXN_ID>#{transaction.orderRef}</MERCHANT_TXN_ID><USERNAME>BETLION</USERNAME><PASSWORD>BET_AUTH</PASSWORD><REFERENCE_NO>#{transaction.orderRef}</REFERENCE_NO><MESSAGE>Enter Pin To Make Payment</MESSAGE></COMMAND>";
							xml = %{"client_id": "d3c57107-fd9a-4ea6-9aa1-461ac69384b0", "client_secret": "7ec36e58-d805-4076-9910-4a050328ce3c", "grant_type": "client_credentials"}
							IO.inspect "xml3"
							IO.inspect xml
							xml = Jason.encode!(xml);
							options = [];		
							#ssl: [{:versions, [:'tlsv3']}], recv_timeout: 5000
							header = [{"Content-Type", "application/json"}, {"Accept", "*/*"}];
							
							
							

							case HTTPoison.request(:post, url, xml, [{"Content-Type", "application/json"}, {"Accept", "*/*"}]) do
								{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
									IO.inspect "000000000000000000"
									IO.inspect reason
								{:ok, struct} ->
									IO.inspect struct.body
									bearerBody =  Jason.decode!(struct.body)
									IO.inspect bearerBody
									bearer = bearerBody["access_token"]
									IO.inspect bearer
									
									url = "https://openapiuat.airtel.africa/merchant/v1/payments/"
									xml = %{"reference": "#{transaction.orderRef}", "subscriber": %{"country": "ZM", "currency": "ZMW", "msisdn": "#{mobileNumberTruncated}"}, "transaction": %{"amount": amtToPay, "country": "ZM", "currency": "ZMW", "id": "#{transaction.orderRef}"}}
									xml = Jason.encode!(xml);
									IO.inspect xml
									case HTTPoison.request(:post, url, xml, [{"Content-Type", "application/json"}, {"Accept", "*/*"}, {"X-Country", "ZM"}, {"X-Currency", "ZMW"}, {"Authorization", "Bearer #{bearer}"}]) do
										{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
											IO.inspect "000000000000000000"
											IO.inspect reason
										{:ok, struct} ->
											IO.inspect struct.body
											
									end
							end

							

							#response = %{
							#    Message: "Your fixed deposit of #{productCurrency}#{totalAmount} was successful. You will earn #{productCurrency}#{fixedDeposit.expectedInterest} after #{fixedDeposit.fixedPeriod} #{fixedDeposit.fixedPeriodType}. \n\nPress\nb. Back\n0. Log Out",
							#    ClientState: 2,
							#    Type: "Response",
							#    key: "BA4"
							#}



						else
							Logger.info("Fail")
							#response = %{
							#    Message: "Invalid selection.. Press\n\nb. Back\n0. Log Out",
							#    ClientState: 1,
							#    Type: "Response",
							#    key: "BA3"
							#}
							response = "Invalid selection.. Press\n\nb. Back\n0. Log Out"
							send_response(conn, response)
						end
					end
				_ ->
					response = "Invalid entry.. Press\n\nb. Back\n0. Log Out"
					send_response(conn, response)
            end
        end
    end


    def handle_validate_password_for_pin_change(conn, mobile_number, cmd, text, checkMenu, ussdRequests, valueEntered, client, clientTelco) do

		activeStatus = "ACTIVE";
		query = from au in LoanSavingsSystem.Accounts.User, where: au.username == ^mobile_number, select: au
		loggedInUser = Repo.one(query)


		if(!is_nil(loggedInUser)) do

			if(loggedInUser.status != activeStatus) do
				#response = %{
				#	Message: "Your account is no longer active. Please contact LAXMI to reactivate your account. ",
				#	ClientState: 1,
				#	Type: "Response",
				#	key: "END"
				#}
				logUssdRequest(loggedInUser.id, "PASSWORD CHANGE", nil, "FAILED", mobile_number, "Validate OTP sent for Password Change Failed. Account is #{loggedInUser.status}");
				response = "Your account is no longer active. Please contact Microfinance Zambia to reactivate your account. "
				end_session(ussdRequests, conn, response);
			else
				passwordChecker = Base.encode16(:crypto.hash(:sha512, valueEntered))
				pwsdpin = String.trim_trailing(loggedInUser.pin, " ")
				passwordChecker1 = String.trim_trailing(pwsdpin, " ")
				IO.inspect "passwordChecker..."
				IO.inspect passwordChecker
				IO.inspect loggedInUser.pin
				IO.inspect passwordChecker1

				case String.equivalent?(passwordChecker, passwordChecker1) do
					false ->
						logUssdRequest(loggedInUser.id, "PASSWORD CHANGE", nil, "FAILED", mobile_number, "Validate OTP sent for Password Change Failed. User failed to provide correct password");
						if(loggedInUser.password_fail_count>2) do
						
							logUssdRequest(loggedInUser.id, "PASSWORD CHANGE", nil, "FAILED", mobile_number, "Account blocked due to failure to provide correct password");
							attrs = %{password_fail_count: 3, status: "BLOCKED"}

							loggedInUser
							|> User.changeset(attrs)
							|> Repo.update()
						else

							attrs = %{password_fail_count: (loggedInUser.password_fail_count + 1)}

							loggedInUser
							|> User.changeset(attrs)
							|> Repo.update()
						end


						IO.inspect "checkMenu"
                        IO.inspect checkMenu
                        checkMenuSize = Enum.count(checkMenu) - 5;
                        checkMenuUpd = Enum.slice(checkMenu, 0..checkMenuSize)
                        IO.inspect checkMenuUpd
                        IO.inspect checkMenuSize
                        #IO.inspect Enum.join(checkMenuUpd, "*");

                        text = Enum.join(checkMenuUpd, "*");
                        IO.inspect text
                        text = text <> "*";
                        IO.inspect text
                        attrs = %{request_data: text}
                        IO.inspect attrs

                        ussdRequest = Enum.at(ussdRequests, 0);

                        query = from au in UssdRequest, where: au.id == ^ussdRequest.id, select: au
                            ussdRequest = Repo.one(query);
                        IO.inspect ussdRequest
                        #ussdRequest = Ecto.Changeset.change ussdRequest, request_data: text
                        #case Repo.update ussdRequest do
                        #	{:ok, struct} ->
                        #		IO.inspect ""
                        #		IO.inspect struct
                        #		Repo.transaction()

                        #	{:error, changeset} ->
                        #		IO.inspect changeset
                        #end
                        #UssdRequest.changesetForUpdate(ussdRequest, attrs)
                        #|> prepare_update(conn, ussdRequest)
                        #|> Repo.transaction()
                        ussdRequest
                        |> UssdRequest.changesetForUpdate(attrs)
                        |> Repo.update()
						session_id = ussdRequest.session_id;
						
						
						


                        send_response(conn, "Invalid pin entered. Enter your current pin")
                        #handleChangePin(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, "Invalid Pin. Please provide your valid pin. Your account will be locked if you fail to provide a valid pin after 3 times\nb. Back \n0. End")
						#handleChangePin(conn, mobile_number, cmd, text, ussdRequests, "Invalid credentials. Please log in again. Your account will be locked if you fail to log in after 3 times\nb. Back \n0. End", client, clientTelco);

					true ->

                        attrs = %{password_fail_count: 0, status: "ACTIVE"}

							loggedInUser
							|> User.changeset(attrs)
							|> Repo.update()

						ussdRequest = Enum.at(ussdRequests, 0);
						session_id = ussdRequest.session_id;

						Logger.info (ussdRequest.id);
						logUssdRequest(loggedInUser.id, "PASSWORD CHANGE", nil, "SUCCESS", mobile_number, "Validate OTP sent for Password Change");


						query = from au in UssdRequest, where: au.mobile_number == ^mobile_number and au.session_id == ^session_id, select: au
						ussdRequests = Repo.all(query);
						response = "Enter New 4-digit Pin\n\nb. Cancel\n0. End"
			            send_response(conn, response)
				end
			end

		else

			#response = %{
			#	Message: "Invalid credentials.",
			#	ClientState: 1,
			#	Type: "Response",
			#	key: "END"
			#}
			response = "Invalid credentials."
			end_session(ussdRequests, conn, response);
		end

	end

    def handleChangePin(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, passwordRequestMessage) do
        checkMenuLength = Enum.count(checkMenu)
        defaultCurrency = client.defaultCurrencyId
        valueEntered = Enum.at(checkMenu, (checkMenuLength-4))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);

        query_params = conn.query_params;
        session_id = query_params["SESSION_ID"];
        query = from au in UssdRequest, where: au.mobile_number == ^mobile_number and au.session_id == ^session_id, select: au
        ussdRequests = Repo.all(query);
        ussdRequest = Enum.at(ussdRequests, 0);
        Logger.info (Enum.count(ussdRequests));
        #handle_validate_password_for_pin_change(conn, mobile_number, cmd, text, checkMenu, ussdRequests, valueEntered, client, clientTelco)



        Logger.info text
		orginal_short_code = cmd


		activeStatus = "ACTIVE";
		query = from au in LoanSavingsSystem.Accounts.User, where: au.username == ^mobile_number and au.status == ^activeStatus, select: au
		companyStaff = Repo.one(query)

		if(!is_nil(companyStaff)) do
			checkMenu = String.split(text, "\*")
			checkMenuLength = Enum.count(checkMenu)

			Logger.info("[[[[[[]]]]]]")
			Logger.info(checkMenuLength)
			Logger.info(checkMenu)

            case checkMenuLength do
                4 ->
                    response = passwordRequestMessage
                    send_response(conn, response)
                5 ->
                    valueEntered = Enum.at(checkMenu, (Enum.count(checkMenu)-2))
                    Logger.info (valueEntered);
                    handle_validate_password_for_pin_change(conn, mobile_number, cmd, text, checkMenu, ussdRequests, valueEntered, client, clientTelco)
                6 ->
                    pin = Enum.at(checkMenu, 4)
                    IO.inspect "pin..." <> pin
                    checkDigits = Regex.match?(~r/^([0-9]{4})+$/, pin)
                    case checkDigits do
                        true ->
                            #response = %{
                            #    Message: "Retype the 4-Digit security pin again",
                            #    ClientState: 1,
                            #    Type: "Response",
                            #    key: "CON"
                            #}

                            response = "Retype the 4-Digit security pin again\n\nb. Cancel\n0. End"
                            send_response(conn, response)
                        false ->
                            IO.inspect "checkMenu"
                            IO.inspect checkMenu
                            checkMenuSize = Enum.count(checkMenu) - 2;
                            checkMenuUpd = Enum.slice(checkMenu, 0..checkMenuSize)
                            IO.inspect checkMenuUpd
                            IO.inspect checkMenuSize
                            #IO.inspect Enum.join(checkMenuUpd, "*");

                            text = Enum.join(checkMenuUpd, "*");
                            IO.inspect text
                            text = text <> "*";
                            IO.inspect text
                            attrs = %{request_data: text}
                            IO.inspect attrs

                            ussdRequest = Enum.at(ussdRequests, 0);

                            query = from au in UssdRequest, where: au.id == ^ussdRequest.id, select: au
                                ussdRequest = Repo.one(query);
                            IO.inspect ussdRequest
                            #ussdRequest = Ecto.Changeset.change ussdRequest, request_data: text
                            #case Repo.update ussdRequest do
                            #	{:ok, struct} ->
                            #		IO.inspect ""
                            #		IO.inspect struct
                            #		Repo.transaction()

                            #	{:error, changeset} ->
                            #		IO.inspect changeset
                            #end
                            #UssdRequest.changesetForUpdate(ussdRequest, attrs)
                            #|> prepare_update(conn, ussdRequest)
                            #|> Repo.transaction()
                            ussdRequest
                            |> UssdRequest.changesetForUpdate(attrs)
                            |> Repo.update()


                            #response = %{
                            #    Message: "Incorrect values provided. Please enter a valid 4-digit security pin",
                            #    ClientState: 1,
                            #    Type: "Response",
                            #    key: "CON"
                            #}

                            response = "Incorrect values provided. Please enter your valid 4-digit security pin\nb. Cancel\n0. End"
                            send_response(conn, response)

                    end
                7 ->
                    #password = Enum.at(checkMenu, 4)
                    #cpassword = Enum.at(checkMenu, 5)

                    pin = Enum.at(checkMenu, 4)
                    rpin = Enum.at(checkMenu, 5)
                    IO.inspect "pin..." <> pin
                    IO.inspect "rpin..." <> rpin
                    checkDigits = Regex.match?(~r/^([0-9]{4})+$/, pin)

                    case checkDigits do
                        false ->
                            #response = %{
                            #    Message: "Retype the 4-Digit security pin again",
                            #    ClientState: 1,
                            #    Type: "Response",
                            #    key: "CON"
                            #}
                            IO.inspect "checkMenu"
                            IO.inspect checkMenu
                            checkMenuSize = Enum.count(checkMenu) - 2;
                            checkMenuUpd = Enum.slice(checkMenu, 0..checkMenuSize)
                            IO.inspect checkMenuUpd
                            IO.inspect checkMenuSize
                            #IO.inspect Enum.join(checkMenuUpd, "*");

                            text = Enum.join(checkMenuUpd, "*");
                            IO.inspect text
                            text = text <> "*";
                            IO.inspect text
                            attrs = %{request_data: text}
                            IO.inspect attrs

                            ussdRequest = Enum.at(ussdRequests, 0);

                            query = from au in UssdRequest, where: au.id == ^ussdRequest.id, select: au
                                ussdRequest = Repo.one(query);
                            IO.inspect ussdRequest
                            #ussdRequest = Ecto.Changeset.change ussdRequest, request_data: text
                            #case Repo.update ussdRequest do
                            #	{:ok, struct} ->
                            #		IO.inspect ""
                            #		IO.inspect struct
                            #		Repo.transaction()

                            #	{:error, changeset} ->
                            #		IO.inspect changeset
                            #end
                            #UssdRequest.changesetForUpdate(ussdRequest, attrs)
                            #|> prepare_update(conn, ussdRequest)
                            #|> Repo.transaction()
                            ussdRequest
                            |> UssdRequest.changesetForUpdate(attrs)
                            |> Repo.update()


                            #response = %{
                            #    Message: "Incorrect values provided. Please enter a valid 4-digit security pin",
                            #    ClientState: 1,
                            #    Type: "Response",
                            #    key: "CON"
                            #}

                            response = "Invalid pin provided. Retype the 4-Digit security pin again\nb. Cancel\n0. End"
                            send_response(conn, response)
                        true ->
                            case String.equivalent?(pin, rpin) do
                                false ->
                                    #response = %{
                                    #    Message: "Pin mismatch! The pins you have provided did not match. Enter a valid 4-digit security pin",
                                    #    ClientState: 1,
                                    #    Type: "Response",
                                    #    key: "CON"
                                    #}

									logUssdRequest(companyStaff.id, "PASSWORD CHANGE", nil, "FAILED", mobile_number, "Pin Change Failed. Pin mismatch comparing pin with confirmation pin");
                                    response = "Pin mismatch! The pins you have provided did not match. Enter a valid 4-digit security pin\nb. Back\n0. End"
                                    send_response(conn, response)
                                true ->
                                    pinEnc = LoanSavingsSystem.Accounts.User.encrypt_password(pin)
									pinEnc = String.trim_trailing(pinEnc, " ")

                                    attrs = %{pin: pinEnc}
                                    companyStaff
                                    |> LoanSavingsSystem.Accounts.User.changesetforupdate(attrs)
                                    |> Repo.update()


									logUssdRequest(companyStaff.id, "PASSWORD CHANGE", nil, "SUCCESS", mobile_number, "Pin Change Successful");
									
                                    response = "Pin change was successful\n\nb. Back\n0. End"
                                    send_response(conn, response)

                            end
                    end
			end

		else
			#handle_new_account(conn, mobile_number, cmd, text)
			#response = %{
			#	Message: "Invalid profile. An active profile mapped to this number could not be found. \nContact MFZ staff to assist you with reactivating your profile",
			#	ClientState: 1,
			#	Type: "Response",
			#	key: "END"
			#}

			response = "Invalid profile. An active profile mapped to this number could not be found. \nContact MFZ staff to assist you with reactivating your profile";

			send_response(conn, response)
		end

    end

    





	def handleDivest(conn, mobile_number, cmd, text, checkMenu, client, clientTelco) do
        checkMenuLength = Enum.count(checkMenu)
        defaultCurrency = client.defaultCurrencyId
        valueEntered = Enum.at(checkMenu, (checkMenuLength-2))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
        if valueEntered == "b" do
            #response = %{
            #    Message: "BA3",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA3"
            #}

			response = "BA3"
            send_response(conn, response)
        else
            case checkMenuLength do
				4 ->
					response = "Choose your preferred early withdrawal option:\n\n1. Partial Early Withdrawal\n2. Full Early Withdrawal"
					send_response(conn, response)

                5 ->
					if(valueEntered=="1" || valueEntered=="2") do
					
						query = from au in User,
							where: (au.username == type(^mobile_number, :string)),
							select: au
						appUsers = Repo.all(query);
						appUser = Enum.at(appUsers, 0);



						individualRoleType = "INDIVIDUAL"
						query = from au in LoanSavingsSystem.Accounts.UserRole,
							where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
							select: au
						userRoles = Repo.all(query);
						userRole = Enum.at(userRoles, 0);


						status = "Disbursed";
						isMatured = false
						isDivested = false
						fixedDepositStatus = "ACTIVE"
						query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
							where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.fixedDepositStatus == type(^fixedDepositStatus, :string) and au.userId == type(^appUser.id, :integer)),
							order_by: [desc: :id],
							select: au
						fixedDeposits = Repo.all(query);
						totalBalance = 0.00;



							Logger.info "=========="
							Logger.info Enum.count(fixedDeposits)

						if Enum.count(fixedDeposits)>0 do

							#acc = Enum.reduce(fixedDeposits, fn x,
							#    acc -> x.id * acc
							#end)

							totals = for x <- 0..(Enum.count(fixedDeposits)-1) do
								#totalBalance = Enum.each(fixedDeposits, fn(fixedDeposit) ->
								fixedDeposit = Enum.at(fixedDeposits, x);


								query = from au in LoanSavingsSystem.Products.Product,
									where: (au.id == ^fixedDeposit.productId),
									select: au
								products = Repo.all(query);
								product = Enum.at(products, 0);

								period = 0;
								days = Date.diff(Date.utc_today, fixedDeposit.startDate);


								query = from au in LoanSavingsSystem.Divestments.DivestmentPackage,
									where: (au.status == "ACTIVE" and au.productId == ^product.id and au.startPeriodDays <= type(^days, :integer) and au.endPeriodDays >= type(^days, :integer)),
									select: au
								divestmentOption = Repo.one(query);

								if is_nil(divestmentOption) do

								else

									#ntotals = calculate_maturity_repayments(fixedDeposit.principalAmount, days,
									#   divestmentOption.divestmentValuation, fixedDeposit.yearLengthInDays, product.interestMode,
									#   product.interestType, fixedDeposit.fixedPeriodType)
									
									ntotals = fixedDeposit.principalAmount + fixedDeposit.accruedInterest;
									ntotalsAtDueDate = fixedDeposit.principalAmount + fixedDeposit.expectedInterest
									fullValue = Float.ceil(ntotalsAtDueDate, fixedDeposit.currencyDecimals)

									Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
									Logger.info ntotals
									endDate = case fixedDeposit.fixedPeriodType do
										"Days" ->
											endDate = Date.add(Date.utc_today, fixedDeposit.fixedPeriod)
											endDate
										"Months" ->
											endDate = Date.add(Date.utc_today, fixedDeposit.fixedPeriod*30)
											endDate
										"Years" ->
											endDate = Date.add(Date.utc_today, fixedDeposit.fixedPeriod*fixedDeposit.yearLengthInDays)
											endDate
									end
									#currentValue = Float.ceil(ntotals, fixedDeposit.currencyDecimals)
									currentValue = Decimal.round(Decimal.from_float(ntotals), fixedDeposit.currencyDecimals)
									#currentValue = :erlang.float_to_binary((currentValue), [{:decimals, fixedDeposit.currencyDecimals}])

									fixedAmount = Float.ceil(fixedDeposit.principalAmount, fixedDeposit.currencyDecimals)
									fixedAmount = :erlang.float_to_binary((fixedAmount), [{:decimals, fixedDeposit.currencyDecimals}])
									id = "#{fixedDeposit.id}";
									idLen = String.length(id);

									fixedDepositNumber = String.pad_leading("#{fixedDeposit.id}", (6 - idLen), "0");
									"#{(x+1)}. Ref ##{fixedDepositNumber}\nFixed Deposit: " <> fixedDeposit.currency <> fixedAmount <> "\nCurrent Value: " <> fixedDeposit.currency <> "#{currentValue}" <> "\nValue At Maturity: " <> fixedDeposit.currency <> "#{fullValue}\nValue Date: #{endDate}\n"
									#\nDeposit Date: #{fixedDeposit.startDate}
								end

							end


							Logger.info Enum.count(totals)
							Logger.info "==========>>>>>>>"
							acctStatement = (Enum.join(totals, "\n");)
							IO.inspect String.length(acctStatement);
							text = "Select a fixed deposit to divest \n\n" <> acctStatement <> "\n\nb. Back \n0. End";
							#response = %{
							#    Message: text,
							#    ClientState: 1,
							#    Type: "Response",
							#    key: "CON"
							#}

							response = text
							send_response(conn, response)
						else
							text = "You do not have any fixed Deposits to divest\n\nb. Back \n0. End";
							response = text;
							send_response(conn, response)
						end
					else 
						text = "Invalid option selected\n\nb. Back \n0. End";
						response = text;
						send_response(conn, response)
					end
                6 ->

                    Logger.info "<<<<==========>>>>"
                    selectedIndex = Enum.at(checkMenu, 4)
                    Logger.info selectedIndex
					
					if(checkIfInteger(selectedIndex)==false) do
						text = "Invalid option selected\n\nb. Back \n0. End";
						response = text;
						send_response(conn, response)
					else
						selectedIndex = elem Integer.parse(selectedIndex), 0
						query = from au in User,
							where: (au.username == type(^mobile_number, :string)),
							select: au
						appUsers = Repo.all(query);
						appUser = Enum.at(appUsers, 0);



						individualRoleType = "INDIVIDUAL"
						query = from au in LoanSavingsSystem.Accounts.UserRole,
							where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
							select: au
						userRoles = Repo.all(query);
						userRole = Enum.at(userRoles, 0);


						status = "Disbursed";
						isMatured = false
						isDivested = false
						query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
							where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.userId >= type(^appUser.id, :integer)),
							select: au
						fixedDeposits = Repo.all(query);
						totalBalance = 0.00;

							Logger.info "=========="
							Logger.info Enum.count(fixedDeposits)

						if (Enum.count(fixedDeposits)>0 && Enum.count(fixedDeposits)>=selectedIndex) do


							#totalBalance = Enum.each(fixedDeposits, fn(fixedDeposit) ->
							fixedDeposit = Enum.at(fixedDeposits, (selectedIndex-1));


							query = from au in LoanSavingsSystem.Products.Product,
								where: (au.id == ^fixedDeposit.productId),
								select: au
							products = Repo.all(query);
							product = Enum.at(products, 0);

							period = 0;
							days = Date.diff(Date.utc_today, fixedDeposit.startDate)


							ntotals = calculate_maturity_repayments(fixedDeposit.principalAmount, days,
							   fixedDeposit.interestRate, fixedDeposit.yearLengthInDays, product.interestMode,
							   product.interestType, fixedDeposit.fixedPeriodType)
							   
							accruedtotals = fixedDeposit.principalAmount + fixedDeposit.accruedInterest;


							daysAtEnd = Date.diff(Date.utc_today, fixedDeposit.startDate)
							ntotalsAtDueDate = fixedDeposit.principalAmount + fixedDeposit.expectedInterest

							Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
							Logger.info ntotals
							endDate = case fixedDeposit.fixedPeriodType do
								"Days" ->
									endDate = Date.add(Date.utc_today, fixedDeposit.fixedPeriod)
									endDate
								"Months" ->
									endDate = Date.add(Date.utc_today, fixedDeposit.fixedPeriod*30)
									endDate
								"Years" ->
									endDate = Date.add(Date.utc_today, fixedDeposit.fixedPeriod*fixedDeposit.yearLengthInDays)
									endDate
							end

							fullValue = Float.ceil(ntotalsAtDueDate, fixedDeposit.currencyDecimals)
							#currentValue = Float.ceil(ntotals, fixedDeposit.currencyDecimals)
							currentValue = Decimal.round(Decimal.from_float(ntotals), fixedDeposit.currencyDecimals)
							accruedtotals = Decimal.round(Decimal.from_float(accruedtotals), fixedDeposit.currencyDecimals)
							fixedAmount = Float.ceil(fixedDeposit.principalAmount, fixedDeposit.currencyDecimals)
							acctStatement = "Txn Date: #{fixedDeposit.startDate}\nValue Date:#{endDate}\nFixed Deposit:" <> fixedDeposit.currency <> "#{fixedAmount}\n"

							id = "#{fixedDeposit.id}";
							idLen = String.length(id);

							fixedDepositNumber = String.pad_leading("#{fixedDeposit.id}", (6 - idLen), "0");



							fixedAmount = :erlang.float_to_binary((fixedAmount), [{:decimals, fixedDeposit.currencyDecimals}])
							#currentValue = :erlang.float_to_binary((currentValue), [{:decimals, fixedDeposit.currencyDecimals}])


							acctStatement = "Ref ##{fixedDepositNumber}\nFixed Deposit: " <> fixedDeposit.currency <> fixedAmount <> "\nCurrent Interest: " <> fixedDeposit.currency <> "#{accruedtotals}" <> "\nValue At Maturity: " <> fixedDeposit.currency <> "#{fullValue}\nValue Date: #{endDate}\nDeposit Date: #{fixedDeposit.startDate}\n"

							currentDays = Date.diff(Date.utc_today, fixedDeposit.startDate);
							query = from au in LoanSavingsSystem.Divestments.DivestmentPackage,
								where: (au.productId == ^fixedDeposit.productId and au.startPeriodDays <= type(^currentDays, :integer) and au.endPeriodDays >= type(^currentDays, :integer)),
								select: au
							divestmentPackages = Repo.all(query);
							if Enum.count(divestmentPackages) == 0 do
								#response = %{
								#    Message: "You can not divest this fixed product. Contact our customer support team for more assistance on this",
								#    ClientState: 1,
								#    Type: "Response"
								#}

								response = "You can not divest this fixed product. Contact our customer support team for more assistance on this"
								send_response(conn, response)
							else
								#divestmentPackage = Enum.at(divestmentPackages, 0);
								#newValuation = calculate_maturity_repayments(fixedDeposit.principalAmount, days,
								#      fixedDeposit.interestRate, fixedDeposit.yearLengthInDays, product.interestMode,
								#      product.interestType, fixedDeposit.fixedPeriodType)

								Logger.info "=========="
								text = "Your selected fixed deposit:\n\n" <> acctStatement <> "\n1. Confirm\nb. Back \n0. End";
								#response = %{
								#    Message: text,
								#    ClientState: 1,
								#    Type: "Response",
								#    key: "CON"
								#}
								response = text
								send_response(conn, response)
							end
						else
							text = "Invalid selection. Select a valid fixed deposit to divest\nb. Back \n0. End";
							response = text
							send_response(conn, response)
						end
					end
                7 ->
                    #response = %{
                    #    Message: "Enter how much you are withdrawing today.",
                    #    ClientState: 1,
                    #    Type: "Response",
                    #    key: "CON"
                    #}
					
					IO.inspect "88888888888888888888888888888888";
					IO.inspect checkMenu;
					selectedIndex = Enum.at(checkMenu, 3)
                    selectedIndex = elem Integer.parse(selectedIndex), 0
					valueEntered = Enum.at(checkMenu, (Enum.count(checkMenu) - 2))

					if (selectedIndex==1) do		#Partial Divestment
						if(valueEntered=="1") do
							response = "Enter how much you are withdrawing today."
							send_response(conn, response)
						else
							text = "Invalid selection.\nb. Back \n0. End";
							response = text
							send_response(conn, response)
						end
					else
						if (selectedIndex==2) do		#Full Divestment

							if(valueEntered=="1") do
								selectedIndex = Enum.at(checkMenu, 4)
								selectedIndex = elem Integer.parse(selectedIndex), 0
								query = from au in User,
									where: (au.username == type(^mobile_number, :string)),
									select: au
								appUsers = Repo.all(query);
								appUser = Enum.at(appUsers, 0);

								individualRoleType = "INDIVIDUAL"
								query = from au in LoanSavingsSystem.Accounts.UserRole,
									where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
									select: au
								userRoles = Repo.all(query);
								userRole = Enum.at(userRoles, 0);


								status = "Disbursed";
								isMatured = false
								isDivested = false
								query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
									where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.userId >= type(^appUser.id, :integer)),
									select: au
								fixedDeposits = Repo.all(query);
								fixedDeposit = Enum.at(fixedDeposits, (selectedIndex-1));
								totalBalance = 0.00;


								productId = fixedDeposit.productId
								query = from au in LoanSavingsSystem.Products.Product,
									where: (au.id == type(^productId, :integer)) ,
									select: au
								savingsProducts = Repo.all(query)
								savingsProduct = Enum.at(savingsProducts, 0)


								amount = fixedDeposit.principalAmount;
								Logger.info "<<<<<<"
								Logger.info amount

								currentDays = Date.diff(Date.utc_today, fixedDeposit.startDate);
								query = from au in LoanSavingsSystem.Divestments.DivestmentPackage,
									where: (au.productId == ^fixedDeposit.productId and au.startPeriodDays <= type(^currentDays, :integer) and au.endPeriodDays >= type(^currentDays, :integer)),
									select: au
								divestmentPackages = Repo.all(query);
								divestmentPackage = Enum.at(divestmentPackages, 0);


								newValuation = calculate_maturity_repayments(amount, currentDays,
									  divestmentPackage.divestmentValuation, fixedDeposit.yearLengthInDays, savingsProduct.interestMode,
									  savingsProduct.interestType, fixedDeposit.fixedPeriodType)
								newValuation = Float.ceil(newValuation, 2);
								totalRepayAmount = Float.ceil(newValuation, fixedDeposit.currencyDecimals)
								newValuation = :erlang.float_to_binary((newValuation), [{:decimals, savingsProduct.currencyDecimals}])

								totalRepayAmount = Float.to_string(totalRepayAmount)
								Logger.info "#{totalRepayAmount}"
								Logger.info "new valuation... #{totalRepayAmount}"


								msg = "If you withdraw today you will receive #{fixedDeposit.currency}#{newValuation}. Please press";
								msg = msg <> "\n\n1. Confirm\nb. Back"
								response = msg
								send_response(conn, response)
							else
							
								msg = "Invalid selection. Press";
								msg = msg <> "\n\nb. Back\n0. End"
								response = msg
								send_response(conn, response)
							end
						end
					end

                8 ->
					selectedIndex = Enum.at(checkMenu, 3)
                    selectedIndex = elem Integer.parse(selectedIndex), 0
					valueEntered = Enum.at(checkMenu, (Enum.count(checkMenu) - 2))

					if (selectedIndex==2) do		#Full Divestment

						keyEntered = "1"
						response = handleDivestFundAction(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, keyEntered, 2)	#FULL DIVESTMENT
						send_response(conn, response)
					else
						if (selectedIndex==1 && checkIfFloat(valueEntered)!==false) do		#Partial Divestment
							selectedIndex = Enum.at(checkMenu, 4)
							selectedIndex = elem Integer.parse(selectedIndex), 0
							query = from au in User,
								where: (au.username == type(^mobile_number, :string)),
								select: au
							appUsers = Repo.all(query);
							appUser = Enum.at(appUsers, 0);

							individualRoleType = "INDIVIDUAL"
							query = from au in LoanSavingsSystem.Accounts.UserRole,
								where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
								select: au
							userRoles = Repo.all(query);
							userRole = Enum.at(userRoles, 0);


							status = "Disbursed";
							isMatured = false
							isDivested = false
							query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
								where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.userId >= type(^appUser.id, :integer)),
								select: au
							fixedDeposits = Repo.all(query);
							fixedDeposit = Enum.at(fixedDeposits, (selectedIndex-1));
							totalBalance = 0.00;


							productId = fixedDeposit.productId
							query = from au in LoanSavingsSystem.Products.Product,
								where: (au.id == type(^productId, :integer)) ,
								select: au
							savingsProducts = Repo.all(query)
							savingsProduct = Enum.at(savingsProducts, 0)


							amount = Enum.at(checkMenu, 6)
							amount = elem Float.parse(amount), 0
							Logger.info "<<<<<<"
							Logger.info amount

							currentDays = Date.diff(Date.utc_today, fixedDeposit.startDate);
							if(currentDays >= fixedDeposit.fixedPeriod) do
								msg = "You can not divest this fixed deposit. The selected fixed deposit is due for maturity. Please use the Withdraw option to withdraw your matured funds. Press\n\nb. Back\n0. Log Out"
								response = msg
								send_response(conn, response)
							else
								query = from au in LoanSavingsSystem.Divestments.DivestmentPackage,
									where: (au.productId == ^fixedDeposit.productId and au.startPeriodDays <= type(^currentDays, :integer) and au.endPeriodDays >= type(^currentDays, :integer)),
									select: au
								divestmentPackages = Repo.all(query);
								divestmentPackage = Enum.at(divestmentPackages, 0);


								newValuation = calculate_maturity_repayments(amount, currentDays,
									  divestmentPackage.divestmentValuation, fixedDeposit.yearLengthInDays, savingsProduct.interestMode,
									  savingsProduct.interestType, fixedDeposit.fixedPeriodType)
								newValuation = Float.ceil(newValuation, 2);
								totalRepayAmount = Float.ceil(newValuation, fixedDeposit.currencyDecimals)
								newValuation = :erlang.float_to_binary((newValuation), [{:decimals, savingsProduct.currencyDecimals}])

								totalRepayAmount = Float.to_string(totalRepayAmount)
								Logger.info "#{totalRepayAmount}"
								Logger.info "new valuation... #{totalRepayAmount}"


								reinvestPeriod = fixedDeposit.fixedPeriod
								balance = (fixedDeposit.principalAmount - amount)
								reinvestCurrency = savingsProduct.currencyId
								
								


								if balance>0 do
									query = from au in LoanSavingsSystem.Products.Product,
										where: (au.minimumPrincipal <= type(^balance, :float) and au.status == "ACTIVE" and au.maximumPrincipal >= type(^balance, :float) and au.defaultPeriod == type(^reinvestPeriod, :integer) and au.currencyId == type(^reinvestCurrency, :integer)) ,
										select: au
									reinvestSavingsProducts = Repo.all(query)

									if Enum.count(reinvestSavingsProducts)== 0 do
										msg = "You can not divest the sum of the amount. You can only divest the full funds your have deposited. Press\n\nb. Back\n0. Log Out"

										#response = %{
										#    Message: msg,
										#    ClientState: 2,
										#    Type: "Response",
										#    key: "BA3"
										#}

										response = msg
										send_response(conn, response)
									else
										Logger.info Enum.count(reinvestSavingsProducts)
										reinvestSavingsProduct = Enum.at(reinvestSavingsProducts, 0)
										reinvestValuationCurrency = reinvestSavingsProduct.currencyName
										reinvestPeriod = reinvestSavingsProduct.defaultPeriod
										reinvestPeriodType = reinvestSavingsProduct.periodType

										reinvestValuation = calculate_maturity_repayments(balance, reinvestPeriod,
											reinvestSavingsProduct.interest, reinvestSavingsProduct.yearLengthInDays, reinvestSavingsProduct.interestMode,
											reinvestSavingsProduct.interestType, reinvestSavingsProduct.periodType)
										reinvestValuation = Float.ceil(reinvestValuation, reinvestSavingsProduct.currencyDecimals)
										reinvestValuation = :erlang.float_to_binary((reinvestValuation), [{:decimals, reinvestSavingsProduct.currencyDecimals}])

										msg = "If you withdraw today you will receive #{fixedDeposit.currency}" <> newValuation <> ". \nThe balance will be reinvested to give you #{reinvestValuationCurrency}#{reinvestValuation} on #{DateTime.to_date(fixedDeposit.endDate)} \n\n1. Confirm\nb. Back"

										#response = %{
										#    Message: msg,
										#    ClientState: 2,
										#    Type: "Response",
										#    key: "CON"
										#}

										response = msg
										send_response(conn, response)
									end
								else
									msg = "If you withdraw today you will receive #{fixedDeposit.currency}#{newValuation}";
									msg = msg <> "\n\n1. Confirm\nb. Back"

									#response = %{
									#    Message: msg,
									#    ClientState: 2,
									#    Type: "Response",
									#    key: "CON"
									#}

									response = msg
									send_response(conn, response)
								end
							end
						else
							text = "Invalid amount entered.\n\nb. Back \n0. End";
							response = text
							send_response(conn, response)
						end
					end

                9 ->
					keyEntered = Enum.at(checkMenu, 7)
                    response = handleDivestFundAction(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, keyEntered, 1)	#For Partial Divestment
					send_response(conn, response)
            end
        end
    end




	def handleDivestFundAction(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, keyEntered, type) do

		response = if keyEntered=="1" do
			selectedIndex = Enum.at(checkMenu, 4)
			selectedIndex = elem Integer.parse(selectedIndex), 0
			query = from au in User,
				where: (au.username == type(^mobile_number, :string)),
				select: au
			appUsers = Repo.all(query);
			appUser = Enum.at(appUsers, 0);

			individualRoleType = "INDIVIDUAL"
			query = from au in LoanSavingsSystem.Accounts.UserRole,
				where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
				select: au
			userRoles = Repo.all(query);
			userRole = Enum.at(userRoles, 0);
			userRoleId = userRole.id
			
			
			query = from au in LoanSavingsSystem.Client.UserBioData,
				where: (au.userId == type(^appUser.id, :integer)),
				select: au
			userBioData = Repo.one(query);


			status = "Disbursed";
			isMatured = false
			isDivested = false
			query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
				where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.userId >= type(^appUser.id, :integer)),
				select: au
			fixedDeposits = Repo.all(query);
			fixedDeposit = Enum.at(fixedDeposits, (selectedIndex-1));
			totalBalance = 0.00;


			productId = fixedDeposit.productId
			query = from au in LoanSavingsSystem.Products.Product,
				where: (au.id == type(^productId, :integer)) ,
				select: au
			savingsProducts = Repo.all(query)
			savingsProduct = Enum.at(savingsProducts, 0)


			amount = if (type==1) do
				amount = Enum.at(checkMenu, 6)
				amount = elem Float.parse(amount), 0
				amount
			else
				amount = if (type==2) do
					amount = fixedDeposit.principalAmount
					amount
				end
				amount
			end
			Logger.info "<<<<<<"
			Logger.info amount

			currentDays = Date.diff(Date.utc_today, fixedDeposit.startDate);
			query = from au in LoanSavingsSystem.Divestments.DivestmentPackage,
				where: (au.productId == ^fixedDeposit.productId and au.startPeriodDays <= type(^currentDays, :integer) and au.endPeriodDays >= type(^currentDays, :integer)),
				select: au
			divestmentPackages = Repo.all(query);
			divestmentPackage = Enum.at(divestmentPackages, 0);


			newValuation = calculate_maturity_repayments(amount, currentDays,
				  divestmentPackage.divestmentValuation, fixedDeposit.yearLengthInDays, savingsProduct.interestMode,
				  savingsProduct.interestType, fixedDeposit.fixedPeriodType)
			accruedInterest = newValuation - amount
			newValuation = Float.ceil(newValuation, 2);
			accruedInterest = Float.ceil(accruedInterest, 2);

			totalRepayAmount = Float.ceil(newValuation, fixedDeposit.currencyDecimals)
			totalRepayAmount = Float.to_string(totalRepayAmount)
			Logger.info "#{totalRepayAmount}"
			Logger.info "new valuation... #{totalRepayAmount}"


			reinvestPeriod = fixedDeposit.fixedPeriod
			balance = (fixedDeposit.principalAmount - amount)
			reinvestCurrency = savingsProduct.currencyId







			query = from au in LoanSavingsSystem.Accounts.Account,
				where: (au.userRoleId == type(^userRole.id, :integer)),
				select: au
			accounts = Repo.all(query);
			account = Enum.at(accounts, 0);
			accountId = account.id
			userId = appUser.id

			carriedOutByUserId= userId
			carriedOutByUserRoleId= userRoleId
			isReversed= false
			orderRef= Integer.to_string(Enum.random(1_000000000..9_999999999))
			orderRef = "ZIPAKE#{orderRef}";
			divestOrderRef = "ZIPAKE#{orderRef}";
			productId= savingsProduct.id
			productType= "SAVINGS"
			referenceNo= Integer.to_string(Enum.random(1_000000000..9_999999999))
			requestData= nil
			responseData= nil
			status= "Success"
			totalAmount= amount
			transactionType= "DR"
			productCurrency= savingsProduct.currencyName
			
			
			

			currentBalance = calculateCurrentBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
			transactionDetail = "Withdrawal before Fixed Deposit Maturity";
			transaction = %LoanSavingsSystem.Transactions.Transaction{
				accountId: accountId,
				carriedOutByUserId: carriedOutByUserId,
				carriedOutByUserRoleId: carriedOutByUserRoleId,
				isReversed: isReversed,
				orderRef: orderRef,
				productId: productId,
				productType: productType,
				referenceNo: referenceNo,
				requestData: requestData,
				responseData: responseData,
				status: status,
				totalAmount: totalAmount,
				transactionType: transactionType,
				userId: userId,
				userRoleId: userRoleId,
				transactionDetail: transactionDetail,
                transactionTypeEnum: "Divestment",
				newTotalBalance: (currentBalance - totalAmount),
				customerName: "#{userBioData.firstName} #{userBioData.lastName}",
				currencyDecimals: fixedDeposit.currencyDecimals,
				currency: fixedDeposit.currency,
				customerName: "#{userBioData.firstName} #{userBioData.lastName}"
			};
			transaction = Repo.insert!(transaction);


			divestmentType = if (type==1) do
				divestmentType = "Partial Divestment"
				divestmentType
			else
				divestmentType = if (type==2) do
					divestmentType = "Full Divestment"
					divestmentType
				end
				divestmentType
			end
			
			divestment = %LoanSavingsSystem.Divestments.Divestment{
				clientId: client.id,
				divestAmount: amount,
				divestmentDate: Date.utc_today,
				divestmentDayCount: currentDays,
				divestmentValuation: divestmentPackage.divestmentValuation,
				fixedDepositId: fixedDeposit.id,
				fixedPeriod: fixedDeposit.fixedPeriod,
				interestRate: fixedDeposit.interestRate,
				interestRateType: fixedDeposit.interestRateType,
				principalAmount: fixedDeposit.principalAmount,
				interestAccrued: accruedInterest,
				userId: userId,
				userRoleId: userRoleId,
				customerName: "#{userBioData.firstName} #{userBioData.lastName}",
				divestmentType: divestmentType,
				currencyDecimals: fixedDeposit.currencyDecimals,
				currency: fixedDeposit.currency
			};
			divestment = Repo.insert!(divestment);




			divestmentTransaction = %LoanSavingsSystem.Divestments.DivestmentTransaction{
				clientId: client.id,
				amountDivested: amount,
				divestmentId: divestment.id,
				interestAccrued: accruedInterest,
				transactionId: transaction.id,
				userId: userId,
				userRoleId: userRoleId
			};
			divestmentTransaction = Repo.insert!(divestmentTransaction);


			fd = Repo.get!(LoanSavingsSystem.FixedDeposit.FixedDeposits, fixedDeposit.id)
			cs = LoanSavingsSystem.FixedDeposit.FixedDeposits.changeset(fd,
				%{
					accountId: fd.accountId, productId: fd.productId, principalAmount: fd.principalAmount, fixedPeriod: fd.fixedPeriod, fixedPeriodType: fd.fixedPeriodType,
					interestRate: fd.interestRate, interestRateType: fd.interestRateType, expectedInterest: fd.expectedInterest, accruedInterest: fd.accruedInterest,
					isMatured: fd.isMatured, isDivested: true, divestmentPackageId: divestmentPackage.id, currencyId: fd.currencyId,
					currency: fd.currency, currencyDecimals: fd.currencyDecimals, yearLengthInDays: fd.yearLengthInDays, totalDepositCharge: fd.totalDepositCharge,
					totalWithdrawalCharge: fd.totalWithdrawalCharge, totalPenalties: fd.totalPenalties, userRoleId: fd.userRoleId, userId: fd.userId,
					totalAmountPaidOut: totalAmount, startDate: fd.startDate, endDate: fd.endDate, clientId: fd.clientId, divestmentId: divestment.id,
					productInterestMode: fd.productInterestMode, branchId: fd.branchId,
					divestedInterestRate: divestmentPackage.divestmentValuation, divestedInterestRateType: fixedDeposit.fixedPeriodType,
					amountDivested: amount, divestedInterestAmount: accruedInterest, divestedPeriod: currentDays
				})
			Repo.update!(cs)
			
			
			amtWithdrawnAndSentToAirtel = Decimal.round(Decimal.from_float(amount), fixedDeposit.currencyDecimals)
			idLen1 = String.length("#{fixedDeposit.id}");
			fixedDepositNumber1 = String.pad_leading("#{fixedDeposit.id}", (6 - idLen1), "0");
			logUssdRequest(appUser.id, "DIVEST FIXED DEPOSIT", nil, "SUCCESS", mobile_number, "Divested fixed deposit - ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{amtWithdrawnAndSentToAirtel}");
			
			
			url = "https://openapiuat.airtel.africa/auth/oauth2/token";
			xml = %{"client_id": "d3c57107-fd9a-4ea6-9aa1-461ac69384b0", "client_secret": "7ec36e58-d805-4076-9910-4a050328ce3c", "grant_type": "client_credentials"}
			IO.inspect "xml3"
			IO.inspect xml
			xml = Jason.encode!(xml);
			options = [];		
			#ssl: [{:versions, [:'tlsv3']}], recv_timeout: 5000
			header = [{"Content-Type", "application/json"}, {"Accept", "*/*"}];
			
			IO.inspect "CHECKER 3";
			

			case HTTPoison.request(:post, url, xml, [{"Content-Type", "application/json"}, {"Accept", "*/*"}]) do
				{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
					IO.inspect "000000000000000000"
					IO.inspect reason
					customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
						amount: totalAmount,
						fixedDepositId: fixedDeposit.id,
						orderRef: orderRef,
						payoutRequest: xml,
						payoutResponse: "#{reason}",
						payoutType: "DIVESTMENT",
						status: "FAILED",
						transactionDate: Date.utc_today,
						transactionId: transaction.id,
						userId: appUser.id
					}
					customerPayout = Repo.insert!(customerPayout);
					
				{:ok, struct} ->
					IO.inspect struct.body
					bearerBody =  Jason.decode!(struct.body)
					IO.inspect bearerBody
					bearer = bearerBody["access_token"]
					IO.inspect bearer
					
					encryptedPin = "";
					encryptedPin = rsaEncryptDataForAirtel("0000")
					IO.inspect encryptedPin
					mobileNumberTruncated = "";
					mobileNumber = appUser.username;
					IO.inspect mobileNumber;
					mobileNumberTruncated = String.slice(mobileNumber, 3..11);
					
					url = "https://openapiuat.airtel.africa/standard/v1/disbursements/"
					xml = %{"payee": %{"msisdn": "#{mobileNumberTruncated}"}, "reference": "#{orderRef}", "pin": encryptedPin, "transaction": %{"amount": amtWithdrawnAndSentToAirtel, "id": "#{orderRef}"}}
					xml = Jason.encode!(xml);
					IO.inspect xml
					case HTTPoison.request(:post, url, xml, [{"Content-Type", "application/json"}, {"Accept", "*/*"}, {"X-Country", "ZM"}, {"X-Currency", "ZMW"}, {"Authorization", "Bearer #{bearer}"}]) do
						{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
							IO.inspect "000000000000000000"
							IO.inspect reason
							customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
								amount: totalAmount,
								fixedDepositId: fixedDeposit.id,
								orderRef: orderRef,
								payoutRequest: xml,
								payoutResponse: "#{reason}",
								payoutType: "DIVESTMENT",
								status: "FAILED",
								transactionDate: Date.utc_today,
								transactionId: transaction.id,
								userId: appUser.id
							}
							customerPayout = Repo.insert!(customerPayout);
							
						{:ok, struct} ->
							IO.inspect struct.body
							body = struct.body;
							body = Jason.decode!(body)
							status = body['status']['success']
							if(status==true) do
								status = String.downcase(status, :default);
								customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
									amount: totalAmount,
									fixedDepositId: fixedDeposit.id,
									orderRef: orderRef,
									payoutRequest: xml,
									payoutResponse: (body['status']['message']),
									payoutType: "DIVESTMENT",
									status: "SUCCESS",
									transactionDate: Date.utc_today,
									transactionId: transaction.id,
									userId: appUser.id
								}
								customerPayout = Repo.insert!(customerPayout);
								
							else
								customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
									amount: totalAmount,
									fixedDepositId: fixedDeposit.id,
									orderRef: orderRef,
									payoutRequest: xml,
									payoutResponse: (body['status']['message']),
									payoutType: "DIVESTMENT",
									status: "FAILED",
									transactionDate: Date.utc_today,
									transactionId: transaction.id,
									userId: appUser.id
								}
								customerPayout = Repo.insert!(customerPayout);
								
							end
							
					end
			end

			response = if balance>0 do
				query = from au in LoanSavingsSystem.Products.Product,
					where: (au.minimumPrincipal <= type(^balance, :float) and au.status == "ACTIVE" and au.maximumPrincipal >= type(^balance, :float) and au.defaultPeriod == type(^reinvestPeriod, :integer) and au.currencyId == type(^reinvestCurrency, :integer)) ,
					select: au
				reinvestSavingsProducts = Repo.all(query)
				reinvestSavingsProduct = Enum.at(reinvestSavingsProducts, 0)
				reinvestValuationCurrency = reinvestSavingsProduct.currencyName
				reinvestPeriod = reinvestSavingsProduct.defaultPeriod
				reinvestPeriodType = reinvestSavingsProduct.periodType


				reinvestValuation = calculate_maturity_repayments(balance, reinvestPeriod,
					  reinvestSavingsProduct.interest, reinvestSavingsProduct.yearLengthInDays, reinvestSavingsProduct.interestMode,
					  reinvestSavingsProduct.interestType, reinvestSavingsProduct.periodType)
				reinvestValuation = Float.ceil(reinvestValuation, reinvestSavingsProduct.currencyDecimals)


				carriedOutByUserId= userId
				carriedOutByUserRoleId= userRoleId
				isReversed= false
				orderRef= Integer.to_string(Enum.random(1_000000000..9_999999999))
				orderRef = "ZIPAKE#{orderRef}";
				productId= reinvestSavingsProduct.id
				productType= "SAVINGS"
				referenceNo= Integer.to_string(Enum.random(1_000000000..9_999999999))
				requestData= nil
				responseData= nil
				status= "Success"
				totalAmount= amount
				transactionType= "CR"
				productCurrency= reinvestSavingsProduct.currencyName




				expectedInterest= Float.ceil((reinvestValuation - balance), reinvestSavingsProduct.currencyDecimals)
				fixedPeriod= reinvestSavingsProduct.defaultPeriod
				fixedPeriodType= reinvestSavingsProduct.periodType
				interestRate= reinvestSavingsProduct.interest
				interestRateType= reinvestSavingsProduct.interestType
				isDivested= false
				isMatured= false
				principalAmount= balance
				productId= reinvestSavingsProduct.id
				startDate= fd.startDate
				totalAmountPaidOut= 0.00
				totalDepositCharge= 0.00
				totalPenalties= 0.00
				totalWithdrawalCharge= 0.00
				yearLengthInDays= reinvestSavingsProduct.yearLengthInDays
				accruedInterest = 0.00
				currencyId = reinvestSavingsProduct.currencyId
				currencyDecimals = reinvestSavingsProduct.currencyDecimals
				currency = reinvestSavingsProduct.currencyName
				endDate = fd.endDate
				fixedDepositStatus = "ACTIVE"
				productInterestMode= reinvestSavingsProduct.interestMode


				fixedDeposit = %LoanSavingsSystem.FixedDeposit.FixedDeposits{
					accountId: accountId,
					accruedInterest: accruedInterest,
					clientId: client.id,
					currency: currency,
					currencyDecimals: currencyDecimals,
					currencyId: currencyId,
					endDate: endDate,
					expectedInterest: expectedInterest,
					fixedPeriod: fixedPeriod,
					fixedPeriodType: fixedPeriodType,
					interestRate: interestRate,
					interestRateType: interestRateType,
					isDivested: isDivested,
					isMatured: isMatured,
					principalAmount: principalAmount,
					productId: productId,
					startDate: startDate,
					totalAmountPaidOut: totalAmountPaidOut,
					totalDepositCharge: totalDepositCharge,
					totalPenalties: totalPenalties,
					totalWithdrawalCharge: totalWithdrawalCharge,
					userId: userId,
					userRoleId: userRoleId,
					yearLengthInDays: yearLengthInDays,
					fixedDepositStatus: fixedDepositStatus,
					productInterestMode: productInterestMode,
					customerName: "#{userBioData.firstName} #{userBioData.lastName}"
				}
				fixedDeposit = Repo.insert!(fixedDeposit);


				currentBalance = calculateCurrentBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
				transactionDetail = "Fixed Deposit on Balance";
				transaction = %LoanSavingsSystem.Transactions.Transaction{
					accountId: accountId,
					carriedOutByUserId: carriedOutByUserId,
					carriedOutByUserRoleId: carriedOutByUserRoleId,
					isReversed: isReversed,
					orderRef: orderRef,
					productId: productId,
					productType: productType,
					referenceNo: referenceNo,
					requestData: requestData,
					responseData: responseData,
					status: status,
					totalAmount: balance,
					transactionType: transactionType,
					userId: userId,
					userRoleId: userRoleId,
					transactionDetail: transactionDetail,
					transactionTypeEnum: "Deposit",
					newTotalBalance: (currentBalance),
					customerName: "#{userBioData.firstName} #{userBioData.lastName}",
					currencyDecimals: currencyDecimals,
					currency: currency
				};
				transaction = Repo.insert!(transaction);

				fixedDepositTransaction = %LoanSavingsSystem.FixedDeposit.FixedDepositTransaction{
					clientId: client.id,
					fixedDepositId: fixedDeposit.id,
					amountDeposited: principalAmount,
					transactionId: transaction.id,
					userId: userId,
					userRoleId: userRoleId,
					status: "SUCCESSFUL"
				};
				fixedDepositTransaction = Repo.insert!(fixedDepositTransaction);

				newValuation = :erlang.float_to_binary((newValuation), [{:decimals, savingsProduct.currencyDecimals}])
				balance = :erlang.float_to_binary((balance), [{:decimals, reinvestSavingsProduct.currencyDecimals}])
				msg = "The sum of #{fixedDeposit.currency}#{newValuation} has been paid into your Airtel mobile money account.\n\nThe balance of #{reinvestValuationCurrency}#{balance} has also been fixed for #{reinvestPeriod}  #{reinvestPeriodType} to yield you #{reinvestValuationCurrency}#{reinvestValuation}\n\nb. Back\n0. End"



				query = from au in LoanSavingsSystem.Client.UserBioData,
					where: (au.userId == type(^userId, :integer)),
					select: au
				userBioData = Repo.one(query);
				firstName = userBioData.firstName;
				
				
				idLen1 = String.length("#{fixedDeposit.id}");
				fixedDepositNumber1 = String.pad_leading("#{fixedDeposit.id}", (6 - idLen1), "0");
				idLen2 = String.length("#{fd.id}");
				fixedDepositNumber2 = String.pad_leading("#{fd.id}", (6 - idLen2), "0");
				
				logUssdRequest(appUser.id, "FIXED DEPOSIT", nil, "SUCCESS", mobile_number, "Fixed deposit - #{userBioData.firstName} #{userBioData.lastName} | ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{balance} | Reinvestment From ##{fixedDepositNumber2}");


				naive_datetime = Timex.now
				sms = %{
					mobile: appUser.username,
					msg: "Dear #{firstName},\nYour withdrawal of #{fixedDeposit.currency}" <> newValuation <> " was been queued for payment into your Airtel mobile money account.\nOrder Ref: #{divestOrderRef}",
					status: "READY",
					type: "SMS",
					msg_count: "1",
					date_sent: naive_datetime
				}
				Sms.changeset(%Sms{}, sms)
				|> Repo.insert()


				naive_datetime = Timex.now
				sms = %{
					mobile: appUser.username,
					msg: "Dear #{firstName}, The balance of #{reinvestValuationCurrency}#{balance} has been fixed for #{reinvestPeriod}  #{reinvestPeriodType} to yield you #{reinvestValuationCurrency}#{reinvestValuation}\nOrder Ref: #{orderRef}",
					status: "READY",
					type: "SMS",
					msg_count: "1",
					date_sent: naive_datetime
				}
				Sms.changeset(%Sms{}, sms)
				|> Repo.insert()

				#response = %{
				#    Message: msg,
				#    ClientState: 2,
				#    Type: "Response",
				#    key: "CON"
				#}
				response = msg
				response
			else
				newValuation = :erlang.float_to_binary((newValuation), [{:decimals, savingsProduct.currencyDecimals}])
				msg = "The sum of #{fixedDeposit.currency}#{newValuation} has been queued for payment into your mobile money account. Thanks\n\n\nb. Back\n0. End"

				#response = %{
				#    Message: msg,
				#    ClientState: 2,
				#    Type: "Response",
				#    key: "CON"
				#}

				query = from au in LoanSavingsSystem.Client.UserBioData,
					where: (au.userId == type(^userId, :integer)),
					select: au
				userBioData = Repo.one(query);
				firstName = userBioData.firstName;

				naive_datetime = Timex.now
				sms = %{
					mobile: appUser.username,
					msg: "Dear #{firstName}, Your withdrawal of #{fixedDeposit.currency}" <> newValuation <> " has been queued for payment into your Airtel mobile money account.\nOrder Ref: #{divestOrderRef}",
					status: "READY",
					type: "SMS",
					msg_count: "1",
					date_sent: naive_datetime
				}
				Sms.changeset(%Sms{}, sms)
				|> Repo.insert()


				response = msg
				response
			end
			response


		else

			#response = %{
			#    Message: "Invalid selection.. Press\n\nb. Back\n0. Log Out",
			#    ClientState: 1,
			#    Type: "Response",
			#    key: "BA3"
			#}
			response = "Invalid selection.. Press\n\nb. Back\n0. Log Out"
			response
		end

		response
	end



    def handleWithdrawal(conn, mobile_number, cmd, text, checkMenu, client, clientTelco) do
        checkMenuLength = Enum.count(checkMenu)
        defaultCurrency = client.defaultCurrencyId
        valueEntered = Enum.at(checkMenu, (checkMenuLength-1))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
		query = from au in User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUsers = Repo.all(query);
		appUser = Enum.at(appUsers, 0);
        if valueEntered == "b" do
            #response = %{
            #    Message: "BA3",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA3"
            #}

			response = "BA3"
            send_response(conn, response)
        else
            case checkMenuLength do
                4 ->
                    
                    individualRoleType = "INDIVIDUAL"
                    query = from au in LoanSavingsSystem.Accounts.UserRole,
                        where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
                        select: au
                    userRoles = Repo.all(query);
                    userRole = Enum.at(userRoles, 0);


                    status = "Disbursed";
                    isMatured = true
                    isWithdrawn = false
                    query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
                        where: (au.isMatured == type(^isMatured, :boolean) and au.isWithdrawn == type(^isWithdrawn, :boolean) and au.userId == type(^appUser.id, :integer)),
                        select: au
                    fixedDeposits = Repo.all(query);
                    totalBalance = 0.00;



                        Logger.info "=========="
                        Logger.info Enum.count(fixedDeposits)

                    if Enum.count(fixedDeposits)>0 do

                        #acc = Enum.reduce(fixedDeposits, fn x,
                        #    acc -> x.id * acc
                        #end)

                        totals = for x <- 0..(Enum.count(fixedDeposits)-1) do
                            #totalBalance = Enum.each(fixedDeposits, fn(fixedDeposit) ->
                            fixedDeposit = Enum.at(fixedDeposits, x);

							currentValue = Float.ceil((fixedDeposit.principalAmount + fixedDeposit.accruedInterest), fixedDeposit.currencyDecimals)
							currentValue = :erlang.float_to_binary((currentValue), [{:decimals, fixedDeposit.currencyDecimals}])

							#fixedAmount = Float.ceil(fixedDeposit.principalAmount, fixedDeposit.currencyDecimals)
							#fixedAmount = :erlang.float_to_binary((fixedAmount), [{:decimals, fixedDeposit.currencyDecimals}])
							fixedAmount = Decimal.round(Decimal.from_float((fixedDeposit.principalAmount)), fixedDeposit.currencyDecimals)
							id = "#{fixedDeposit.id}";
							idLen = String.length(id);

							fixedDepositNumber = String.pad_leading("#{fixedDeposit.id}", (6 - idLen), "0");
							retStr = "#{(x+1)}. Ref ##{fixedDepositNumber}\nFixed Deposit: #{fixedDeposit.currency}#{fixedAmount}\nAmount Due: #{fixedDeposit.currency}#{currentValue}\n\n"
							retStr
                        end


                        Logger.info Enum.count(totals)
                        Logger.info "=========="
                        acctStatement = (Enum.join(totals, "\n");)
                        text = "Select a fixed deposit to withdraw \n\n" <> acctStatement <> "\n\nb. Back \n0. End";
                        #response = %{
                        #    Message: text,
                        #    ClientState: 1,
                        #    Type: "Response",
                        #    key: "CON"
                        #}

						response = text
                        send_response(conn, response)
					else
						text = "You do not have any matured fixed Deposits to withdraw\n\nb. Back \n0. End";
						response = text;
						send_response(conn, response)
                    end
                5 ->

                    Logger.info "<<<<==========>>>>"
					IO.inspect checkMenu
                    selectedIndex = Enum.at(checkMenu, 3)
                    Logger.info selectedIndex
                    selectedIndex = elem Integer.parse(selectedIndex), 0
                    query = from au in User,
                        where: (au.username == type(^mobile_number, :string)),
                        select: au
                    appUsers = Repo.all(query);
                    appUser = Enum.at(appUsers, 0);



                    individualRoleType = "INDIVIDUAL"
                    query = from au in LoanSavingsSystem.Accounts.UserRole,
                        where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
                        select: au
                    userRoles = Repo.all(query);
                    userRole = Enum.at(userRoles, 0);


                    status = "Disbursed";
                    isMatured = true
                    isWithdrawn = false
                    query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
                        where: (au.isMatured == type(^isMatured, :boolean) and au.isWithdrawn == type(^isWithdrawn, :boolean) and au.userId >= type(^appUser.id, :integer)),
                        select: au
                    fixedDeposits = Repo.all(query);
                    totalBalance = 0.00;

                        Logger.info "=========="
                        Logger.info Enum.count(fixedDeposits)

                    if (Enum.count(fixedDeposits)>0 && (selectedIndex <= Enum.count(fixedDeposits)) && selectedIndex>0) do


                        #totalBalance = Enum.each(fixedDeposits, fn(fixedDeposit) ->
                        fixedDeposit = Enum.at(fixedDeposits, (selectedIndex-1));



                        #fullValue = Float.ceil((fixedDeposit.principalAmount + fixedDeposit.accruedInterest), fixedDeposit.currencyDecimals)
                        currentValue = Float.ceil((fixedDeposit.principalAmount + fixedDeposit.accruedInterest), fixedDeposit.currencyDecimals)
						#currentValue = :erlang.float_to_binary((currentValue), [{:decimals, fixedDeposit.currencyDecimals}])
						currentValue = Decimal.round(Decimal.from_float((fixedDeposit.principalAmount + fixedDeposit.accruedInterest)), fixedDeposit.currencyDecimals)
                        fixedAmount = Float.ceil(fixedDeposit.principalAmount, fixedDeposit.currencyDecimals)
						fixedAmount = :erlang.float_to_binary((fixedAmount), [{:decimals, fixedDeposit.currencyDecimals}])
						id = "#{fixedDeposit.id}";
						idLen = String.length(id);

						fixedDepositNumber = String.pad_leading("#{fixedDeposit.id}", (6 - idLen), "0");
						
						balance = fixedDeposit.principalAmount + fixedDeposit.accruedInterest - fixedDeposit.totalAmountPaidOut;
						balance = :erlang.float_to_binary((balance), [{:decimals, fixedDeposit.currencyDecimals}])
						acctStatement = "Ref ##{fixedDepositNumber}\nFixed Deposit: #{fixedDeposit.currency} #{fixedAmount}\nValue Amount: #{fixedDeposit.currency}#{currentValue}\nBalance: #{fixedDeposit.currency}#{balance}\n\n"

                        Logger.info "=========="
						text = "Your selected fixed deposit:\n\n" <> acctStatement <> "\n1. Withdraw Everything\n2. Withdraw Some Money\n3. Re-invest Some Money\n4. Reinvest Everything\nb. Back \n0. End";
						response = text
						send_response(conn, response)
					else
						text = "Invalid selection.\n\nb. Back \n0. End";
						response = text
						send_response(conn, response)
                    end
                6 ->
                    #response = %{
                    #    Message: "Enter how much you are withdrawing today.",
                    #    ClientState: 1,
                    #    Type: "Response",
                    #    key: "CON"
                    #}

                    query = from au in User,
                        where: (au.username == type(^mobile_number, :string)),
                        select: au
                    appUsers = Repo.all(query);
                    appUser = Enum.at(appUsers, 0);


					Logger.info "<<<<==========>>>>"
                    selectedFdIndex = Enum.at(checkMenu, 3)
                    Logger.info selectedFdIndex
                    selectedFdIndex = elem Integer.parse(selectedFdIndex), 0


					selectedIndex1 = Enum.at(checkMenu, 4)
					case selectedIndex1 do
						"1" ->
							isMatured = true;
							isWithdrawn = false;
							query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
								where: (au.isMatured == type(^isMatured, :boolean) and au.isWithdrawn == type(^isWithdrawn, :boolean) and au.userId >= type(^appUser.id, :integer)),
								select: au
							fixedDeposits = Repo.all(query);
							totalBalance = 0.00;

								Logger.info "=========="
								Logger.info Enum.count(fixedDeposits)

							if (Enum.count(fixedDeposits)>0) do



								Logger.info selectedIndex1
								fixedDeposit = Enum.at(fixedDeposits, (selectedFdIndex-1));


								fd = Repo.get!(LoanSavingsSystem.FixedDeposit.FixedDeposits, fixedDeposit.id)
								cs = LoanSavingsSystem.FixedDeposit.FixedDeposits.changeset(fd,
									%{
										accountId: fd.accountId, productId: fd.productId, principalAmount: fd.principalAmount, fixedPeriod: fd.fixedPeriod, fixedPeriodType: fd.fixedPeriodType,
										interestRate: fd.interestRate, interestRateType: fd.interestRateType, expectedInterest: fd.expectedInterest, accruedInterest: fd.accruedInterest,
										isMatured: fd.isMatured, isDivested: fd.isDivested, currencyId: fd.currencyId,
										currency: fd.currency, currencyDecimals: fd.currencyDecimals, yearLengthInDays: fd.yearLengthInDays, totalDepositCharge: fd.totalDepositCharge,
										totalWithdrawalCharge: fd.totalWithdrawalCharge, totalPenalties: fd.totalPenalties, userRoleId: fd.userRoleId, userId: fd.userId,
										totalAmountPaidOut: (fd.accruedInterest + fd.principalAmount), startDate: fd.startDate, endDate: fd.endDate, clientId: fd.clientId,
										productInterestMode: fd.productInterestMode, branchId: fd.branchId,
										isWithdrawn: true
									})
								Repo.update!(cs)
								
								
								
								
								carriedOutByUserId= appUser.id
								carriedOutByUserRoleId= fd.userRoleId
								isReversed= false
								orderRef= Integer.to_string(Enum.random(1_000000000..9_999999999))
								orderRef = "ZIPAKE#{orderRef}";
								productId= fd.productId
								productType= "SAVINGS"
								referenceNo= Integer.to_string(Enum.random(1_000000000..9_999999999))
								requestData= nil
								responseData= nil
								status= "Success"
								totalAmount= fd.principalAmount + fd.expectedInterest
								transactionType= "CR"
								productCurrency= fd.currencyName


								
								query = from au in LoanSavingsSystem.Client.UserBioData,
									where: (au.userId == type(^appUser.id, :integer)),
									select: au
								userBioData = Repo.one(query);
								transactionDetail = "Fixed Deposit on Balance";
								currentBalance = calculateCurrentBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
								transaction = %LoanSavingsSystem.Transactions.Transaction{
									accountId: fd.accountId,
									carriedOutByUserId: carriedOutByUserId,
									carriedOutByUserRoleId: carriedOutByUserRoleId,
									isReversed: isReversed,
									orderRef: orderRef,
									productId: productId,
									productType: productType,
									referenceNo: referenceNo,
									requestData: requestData,
									responseData: responseData,
									status: status,
									totalAmount: fd.accruedInterest + fd.principalAmount,
									transactionType: transactionType,
									userId: fd.userId,
									userRoleId: fd.userRoleId,
									transactionDetail: transactionDetail,
									newTotalBalance: (currentBalance + totalAmount),
									transactionTypeEnum: "Withdrawal",
									customerName: "#{userBioData.firstName} #{userBioData.lastName}",
									currencyDecimals: fd.currencyDecimals,
									currency: fd.currency
								};
								transaction = Repo.insert!(transaction);
								
								
								amtWithdrawnAndSentToAirtel = Decimal.round(Decimal.from_float(totalAmount), fixedDeposit.currencyDecimals)
								idLen1 = String.length("#{fixedDeposit.id}");
								fixedDepositNumber1 = String.pad_leading("#{fixedDeposit.id}", (6 - idLen1), "0");
								logUssdRequest(appUser.id, "FIXED DEPOSIT WITHDRAWAL", nil, "SUCCESS", mobile_number, "Full Withdrawal On Maturity - ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{amtWithdrawnAndSentToAirtel}");
								
								
								
								url = "https://openapiuat.airtel.africa/auth/oauth2/token";
								xml = %{"client_id": "d3c57107-fd9a-4ea6-9aa1-461ac69384b0", "client_secret": "7ec36e58-d805-4076-9910-4a050328ce3c", "grant_type": "client_credentials"}
								IO.inspect "xml3"
								IO.inspect xml
								xml = Jason.encode!(xml);
								options = [];		
								#ssl: [{:versions, [:'tlsv3']}], recv_timeout: 5000
								header = [{"Content-Type", "application/json"}, {"Accept", "*/*"}];
								
								
								
								IO.inspect "CHECKER 2";

								case HTTPoison.request(:post, url, xml, [{"Content-Type", "application/json"}, {"Accept", "*/*"}]) do
									{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
										IO.inspect "000000000000000000"
										IO.inspect reason
										customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
											amount: amtWithdrawnAndSentToAirtel,
											fixedDepositId: fixedDeposit.id,
											orderRef: orderRef,
											payoutRequest: xml,
											payoutResponse: "#{reason}",
											payoutType: "WITHDRAWAL",
											status: "FAILED",
											transactionDate: Date.utc_today,
											transactionId: transaction.id,
											userId: appUser.id
										}
										customerPayout = Repo.insert!(customerPayout);
										logUssdRequest(appUser.id, "TRANSFER TO CUSTOMER", nil, "FAILED", mobile_number, "Transfer Divestment Queued- #{userBioData.firstName} #{userBioData.lastName} | ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{(amtWithdrawnAndSentToAirtel)}");
									{:ok, struct} ->
										IO.inspect struct.body
										bearerBody =  Jason.decode!(struct.body)
										IO.inspect bearerBody
										bearer = bearerBody["access_token"]
										IO.inspect bearer
										
										encryptedPin = "";
										encryptedPin = rsaEncryptDataForAirtel("0000")
										IO.inspect encryptedPin
										mobileNumberTruncated = "";
										mobileNumber = appUser.username;
										IO.inspect mobileNumber;
										mobileNumberTruncated = String.slice(mobileNumber, 3..11);
										
										url = "https://openapiuat.airtel.africa/standard/v1/disbursements/"
										xml = %{"payee": %{"msisdn": "#{mobileNumberTruncated}"}, "reference": "#{orderRef}", "pin": encryptedPin, "transaction": %{"amount": (amtWithdrawnAndSentToAirtel), "id": "#{orderRef}"}}
										xml = Jason.encode!(xml);
										IO.inspect xml
										case HTTPoison.request(:post, url, xml, [{"Content-Type", "application/json"}, {"Accept", "*/*"}, {"X-Country", "ZM"}, {"X-Currency", "ZMW"}, {"Authorization", "Bearer #{bearer}"}]) do
											{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
												IO.inspect "000000000000000000"
												IO.inspect reason
												customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
													amount: amtWithdrawnAndSentToAirtel,
													fixedDepositId: fixedDeposit.id,
													orderRef: orderRef,
													payoutRequest: xml,
													payoutResponse: "#{reason}",
													payoutType: "WITHDRAWAL",
													status: "FAILED",
													transactionDate: Date.utc_today,
													transactionId: transaction.id,
													userId: appUser.id
												}
												customerPayout = Repo.insert!(customerPayout);
												logUssdRequest(appUser.id, "TRANSFER TO CUSTOMER", nil, "FAILED", mobile_number, "Transfer Divestment Queued- #{userBioData.firstName} #{userBioData.lastName} | ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{(amtWithdrawnAndSentToAirtel)}");
											{:ok, struct} ->
												IO.inspect struct.body
												body = struct.body;
												body = Jason.decode!(body)
												status = body['status']['success']
												if(status==true) do
													status = String.downcase(status, :default);
													customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
														amount: amtWithdrawnAndSentToAirtel,
														fixedDepositId: fixedDeposit.id,
														orderRef: orderRef,
														payoutRequest: xml,
														payoutResponse: (body['status']['message']),
														payoutType: "WITHDRAWAL",
														status: status,
														transactionDate: Date.utc_today,
														transactionId: transaction.id,
														userId: appUser.id
													}
													customerPayout = Repo.insert!(customerPayout);
													logUssdRequest(appUser.id, "TRANSFER TO CUSTOMER", nil, "SUCCESS", mobile_number, "Transfer Divestment Sent - #{userBioData.firstName} #{userBioData.lastName} | ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{(amtWithdrawnAndSentToAirtel)}");
												else
													customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
														amount: amtWithdrawnAndSentToAirtel,
														fixedDepositId: fixedDeposit.id,
														orderRef: orderRef,
														payoutRequest: xml,
														payoutResponse: (body['status']['message']),
														payoutType: "WITHDRAWAL",
														status: status,
														transactionDate: Date.utc_today,
														transactionId: transaction.id,
														userId: appUser.id
													}
													customerPayout = Repo.insert!(customerPayout);
													logUssdRequest(appUser.id, "TRANSFER TO CUSTOMER", nil, "FAILED", mobile_number, "Transfer Divestment Queued- #{userBioData.firstName} #{userBioData.lastName} | ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{(amtWithdrawnAndSentToAirtel)}");
												end
												
										end
								end
			
			


								naive_datetime = Timex.now
								sms = %{
									mobile: "260967307151",
									msg: "Hello,\nYour withdrawal of #{fd.currency}#{(fd.accruedInterest + fd.principalAmount)} has been paid into your Airtel mobile money account.",
									status: "READY",
									type: "SMS",
									msg_count: "1",
									date_sent: naive_datetime
								}
								Sms.changeset(%Sms{}, sms)
								|> Repo.insert()
								Logger.info "=========="
								text = "Your Airtel mobile money account will be credited with the sum of #{fd.currency}#{(fd.accruedInterest + fd.principalAmount)}.\nThank you for your patronage.\n\nb. Back \n0. End";
								response = text
								send_response(conn, response)
							else
								text = "Invalid selection.Press \n\nb. Back \n0. End";
								response = text
								send_response(conn, response)
							end
						"2" ->
							response = "Enter how much you are withdrawing today?"
							send_response(conn, response)
						"3" ->
							handleReinvestSomeMaturedFunds(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, appUser)
						"4" ->
							handleReinvestAllMaturedFunds(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, appUser)
						_ ->
							response = "Invalid selection. Press \n\nb. Back \n0. End"
							send_response(conn, response)
					end


                7 ->
					IO.inspect "########################";
					IO.inspect checkMenu
					parentIndex = Enum.at(checkMenu, 4)
					case parentIndex do
						"2" ->
							#For Partial Withdrawal
							selectedIndex = Enum.at(checkMenu, 3)
							selectedIndex = elem Integer.parse(selectedIndex), 0

							individualRoleType = "INDIVIDUAL"
							query = from au in LoanSavingsSystem.Accounts.UserRole,
								where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
								select: au
							userRoles = Repo.all(query);
							userRole = Enum.at(userRoles, 0);


							status = "Disbursed";
							isMatured = true
							isWithdrawn = false
							query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
								where: (au.isMatured == type(^isMatured, :boolean) and au.isWithdrawn == type(^isWithdrawn, :boolean) and au.userId >= type(^appUser.id, :integer)),
								select: au
							fixedDeposits = Repo.all(query);
							fixedDeposit = Enum.at(fixedDeposits, (selectedIndex-1));
							totalBalance = 0.00;


							productId = fixedDeposit.productId
							query = from au in LoanSavingsSystem.Products.Product,
								where: (au.id == type(^productId, :integer)) ,
								select: au
							savingsProducts = Repo.all(query)
							savingsProduct = Enum.at(savingsProducts, 0)


							amount = Enum.at(checkMenu, 5)
							
							
							if(checkIfFloat(amount)!==false && checkIfFloat(amount)>0) do
								amount = elem Float.parse(amount), 0
								Logger.info "<<<<<<"
								Logger.info amount



								newValuation = :erlang.float_to_binary((fixedDeposit.principalAmount + fixedDeposit.accruedInterest), [{:decimals, savingsProduct.currencyDecimals}])
								amountStr = :erlang.float_to_binary((amount), [{:decimals, savingsProduct.currencyDecimals}])

								Logger.info "#{newValuation}"
								Logger.info "new valuation... #{newValuation}"


								reinvestPeriod = fixedDeposit.fixedPeriod
								balance = (fixedDeposit.principalAmount + fixedDeposit.accruedInterest - amount)
								reinvestCurrency = savingsProduct.currencyId
								reinvestCurrencyName = savingsProduct.currencyName


								if balance>0 do
									query = from au in LoanSavingsSystem.Products.Product,
										where: (au.minimumPrincipal <= type(^balance, :float) and au.status == "ACTIVE" and au.maximumPrincipal >= type(^balance, :float) and au.defaultPeriod == type(^reinvestPeriod, :integer) and au.currencyId == type(^reinvestCurrency, :integer)) ,
										select: au
									reinvestSavingsProducts = Repo.all(query)

									if Enum.count(reinvestSavingsProducts)== 0 do
										msg = "You can not withdraw the amount. You can only divest the full amount your have deposited. Press\n\nb. Back\n0. Log Out"

										#response = %{
										#    Message: msg,
										#    ClientState: 2,
										#    Type: "Response",
										#    key: "BA3"
										#}

										response = msg
										send_response(conn, response)
									else
										Logger.info Enum.count(reinvestSavingsProducts)
										reinvestSavingsProduct = Enum.at(reinvestSavingsProducts, 0)
										reinvestValuationCurrency = reinvestSavingsProduct.currencyName
										reinvestPeriod = reinvestSavingsProduct.defaultPeriod
										reinvestPeriodType = reinvestSavingsProduct.periodType
										reinvestEndDate = case reinvestSavingsProduct.periodType do
											"Days" ->
												endDate = DateTime.add(DateTime.utc_now, (24*60*60*reinvestSavingsProduct.defaultPeriod), :second) |> DateTime.truncate(:second)
												endDate
											"Months" ->
												endDate = DateTime.add(DateTime.utc_now, (24*60*60*reinvestSavingsProduct.defaultPeriod*30), :second) |> DateTime.truncate(:second)
												endDate
											"Years" ->
												endDate = DateTime.add(DateTime.utc_now, (24*60*60*reinvestSavingsProduct.defaultPeriod*reinvestSavingsProduct.yearLengthInDays), :second) |> DateTime.truncate(:second)
												endDate
										end

										reinvestValuation = calculate_maturity_repayments(balance, reinvestPeriod,
											reinvestSavingsProduct.interest, reinvestSavingsProduct.yearLengthInDays, reinvestSavingsProduct.interestMode,
											reinvestSavingsProduct.interestType, reinvestSavingsProduct.periodType)
										reinvestValuation = Float.ceil(reinvestValuation, reinvestSavingsProduct.currencyDecimals)
										reinvestValuation = :erlang.float_to_binary((reinvestValuation), [{:decimals, reinvestSavingsProduct.currencyDecimals}])

										msg = "If you withdraw #{reinvestCurrencyName}#{amountStr}, the balance will be reinvested to give you #{reinvestValuationCurrency}#{reinvestValuation} on #{reinvestEndDate} \n\n1. Confirm\nb. Back"

										#response = %{
										#    Message: msg,
										#    ClientState: 2,
										#    Type: "Response",
										#    key: "CON"
										#}

										response = msg
										send_response(conn, response)
									end
								else
									if balance<0 do
										msg = "Invalid amount. Please try again";
										msg = msg <> "\n\n1. Confirm\nb. Back"

										#response = %{
										#    Message: msg,
										#    ClientState: 2,
										#    Type: "Response",
										#    key: "CON"
										#}

										response = msg
										send_response(conn, response)
									else
										msg = "If you withdraw today you will receive #{fixedDeposit.currency}#{amountStr}";
										msg = msg <> "\n\n1. Confirm\nb. Back"

										#response = %{
										#    Message: msg,
										#    ClientState: 2,
										#    Type: "Response",
										#    key: "CON"
										#}

										response = msg
										send_response(conn, response)
									end
								end
							else
								text = "Invalid amount entered.Press \n\nb. Back \n0. End";
								response = text
								send_response(conn, response)
							end
						"3" ->
							isMatured = true;
							isWithdrawn = false;
							query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
								where: (au.isMatured == type(^isMatured, :boolean) and au.isWithdrawn == type(^isWithdrawn, :boolean) and au.userId >= type(^appUser.id, :integer)),
								select: au
							fixedDeposits = Repo.all(query);
							totalBalance = 0.00;

								Logger.info "=========="
								Logger.info Enum.count(fixedDeposits)

							if (Enum.count(fixedDeposits)>0) do
							
								selectedFdIndex = Enum.at(checkMenu, 3)
								Logger.info selectedFdIndex
								selectedFdIndex = elem Integer.parse(selectedFdIndex), 0


								fixedDeposit = Enum.at(fixedDeposits, (selectedFdIndex-1));


								fd = Repo.get!(LoanSavingsSystem.FixedDeposit.FixedDeposits, fixedDeposit.id)
								totalDueAtMaturity = fd.principalAmount + fd.accruedInterest - fd.totalAmountPaidOut;
								amount = Enum.at(checkMenu, 5)
								amount = elem Float.parse(amount), 0
								if(amount>0 && amount<=totalDueAtMaturity) do
								
									Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
									selectedIndex = Enum.at(checkMenu, 4)
									Logger.info "selectedIndex..."
									Logger.info selectedIndex
									selectedIndex = elem Integer.parse(selectedIndex), 0
									Logger.info selectedIndex
									query = from au in LoanSavingsSystem.Products.Product,
										where: (au.id == type(^fd.productId, :integer)) ,
										select: au
									savingsProduct = Repo.one(query)

									default_rate = savingsProduct.interest
									default_period = savingsProduct.defaultPeriod
									annual_period = savingsProduct.yearLengthInDays
									#amt = elem Integer.parse(amount), 0
									amt = amount


									totalRepayments = calculate_maturity_repayments(amt, default_period, default_rate, annual_period, savingsProduct.interestMode, savingsProduct.interestType, savingsProduct.periodType)
									Logger.info "Test";
									Logger.info ((totalRepayments));

									#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [decimals= savingsProduct.currencyDecimals])
									totalRepayAmount = Float.ceil(totalRepayments, savingsProduct.currencyDecimals)
									#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [{decimals, savingsProduct.currencyDecimals}])
									totalRepayAmount = Float.to_string(totalRepayAmount)
									Logger.info "#{totalRepayAmount}"
									default_period = :erlang.integer_to_binary(default_period)
									repay_entry = default_period <> " " <> savingsProduct.periodType <> " will give you " <> savingsProduct.currencyName <> totalRepayAmount <> ".\nPress \n\n1. Confirm Deposit\nb. Back\n0. End"
									
									
									
									response = repay_entry
									send_response(conn, response)

								else
									text = "The amount you provided to reinvest is more than what you currently have. Please enter a valid amount. Press \n\nb. Back \n0. End";
									response = text
									send_response(conn, response)
								end


								
							else
								text = "Invalid selection.Press \n\nb. Back \n0. End";
								response = text
								send_response(conn, response)
							end
						"4" ->
							isMatured = true;
							isWithdrawn = false;
							query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
								where: (au.isMatured == type(^isMatured, :boolean) and au.isWithdrawn == type(^isWithdrawn, :boolean) and au.userId >= type(^appUser.id, :integer)),
								select: au
							fixedDeposits = Repo.all(query);
							totalBalance = 0.00;

								Logger.info "=========="
								Logger.info Enum.count(fixedDeposits)

							if (Enum.count(fixedDeposits)>0) do
							
								selectedFdIndex = Enum.at(checkMenu, 3)
								Logger.info selectedFdIndex
								selectedFdIndex = elem Integer.parse(selectedFdIndex), 0



								
								fixedDeposit = Enum.at(fixedDeposits, (selectedFdIndex-1));


								fd = Repo.get!(LoanSavingsSystem.FixedDeposit.FixedDeposits, fixedDeposit.id)
								totalDueAtMaturity = fd.principalAmount + fd.accruedInterest - fd.totalAmountPaidOut;
								amount = totalDueAtMaturity
								if(amount>0 && amount<=totalDueAtMaturity) do
								
									Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
									selectedIndex = Enum.at(checkMenu, 4)
									Logger.info "selectedIndex..."
									Logger.info selectedIndex
									selectedIndex = elem Integer.parse(selectedIndex), 0
									Logger.info selectedIndex
									query = from au in LoanSavingsSystem.Products.Product,
										where: (au.id == type(^fd.productId, :integer)) ,
										select: au
									savingsProduct = Repo.one(query)

									default_rate = savingsProduct.interest
									default_period = savingsProduct.defaultPeriod
									annual_period = savingsProduct.yearLengthInDays
									#amt = elem Integer.parse(amount), 0
									amt = amount


									totalRepayments = calculate_maturity_repayments(amt, default_period, default_rate, annual_period, savingsProduct.interestMode, savingsProduct.interestType, savingsProduct.periodType)
									Logger.info "Test";
									Logger.info ((totalRepayments));

									#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [decimals= savingsProduct.currencyDecimals])
									totalRepayAmount = Float.ceil(totalRepayments, savingsProduct.currencyDecimals)
									#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [{decimals, savingsProduct.currencyDecimals}])
									totalRepayAmount = Float.to_string(totalRepayAmount)
									Logger.info "#{totalRepayAmount}"
									default_period = :erlang.integer_to_binary(default_period)
									repay_entry = default_period <> " " <> savingsProduct.periodType <> " gives you " <> savingsProduct.currencyName <> totalRepayAmount <> "  "
									Logger.info "#{totalRepayAmount}"
									Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"


									individualRoleType = "INDIVIDUAL"
									query = from au in LoanSavingsSystem.Accounts.UserRole,
										where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
										select: au
									appUserRoles = Repo.all(query);
									appUserRole = Enum.at(appUserRoles, 0);

									Logger.info "Twst ........";
									Logger.info savingsProduct.id;
									totalCharges = 0.00;

									totalCharge = 0.00;


									query = from au in LoanSavingsSystem.Accounts.Account,
										where: (au.userRoleId == type(^appUserRole.id, :integer)),
										select: au
									accounts = Repo.all(query);
									account = Enum.at(accounts, 0);
									accountId = account.id

									accruedInterest= 0.00
									clientId= client.id
									currency= savingsProduct.currencyName
									currencyDecimals= savingsProduct.currencyDecimals
									currencyId= savingsProduct.currencyId

											Logger.info "%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
											Logger.info savingsProduct.defaultPeriod

									endDate = case savingsProduct.periodType do
										"Days" ->
											endDate = DateTime.add(DateTime.utc_now, (24*60*60*savingsProduct.defaultPeriod), :second) |> DateTime.truncate(:second)
											endDate
										"Months" ->
											endDate = DateTime.add(DateTime.utc_now, (24*60*60*savingsProduct.defaultPeriod*30), :second) |> DateTime.truncate(:second)
											endDate
										"Years" ->
											endDate = DateTime.add(DateTime.utc_now, (24*60*60*savingsProduct.defaultPeriod*savingsProduct.yearLengthInDays), :second) |> DateTime.truncate(:second)
											endDate
									end


									expectedInterest= Float.ceil((totalRepayments - amount), savingsProduct.currencyDecimals)
									fixedPeriod= savingsProduct.defaultPeriod
									fixedPeriodType= savingsProduct.periodType
									interestRate= savingsProduct.interest
									interestRateType= savingsProduct.interestType
									productInterestMode= savingsProduct.interestMode
									isDivested= false
									isMatured= false
									principalAmount= amount
									productId= savingsProduct.id
									startDate= DateTime.utc_now |> DateTime.truncate(:second)
									totalAmountPaidOut= 0.00
									totalDepositCharge= totalCharge
									totalPenalties= 0.00
									totalWithdrawalCharge= 0.00
									userId= appUser.id
									userRoleId= appUserRole.id
									yearLengthInDays= savingsProduct.yearLengthInDays
									fixedDepositStatus = "ACTIVE";
									userId= appUser.id
									query = from au in LoanSavingsSystem.Client.UserBioData,
										where: (au.userId == type(^userId, :integer)),
										select: au
									userBioData = Repo.one(query);

									fixedDeposit = %LoanSavingsSystem.FixedDeposit.FixedDeposits{
										accountId: accountId,
										accruedInterest: accruedInterest,
										clientId: clientId,
										currency: currency,
										currencyDecimals: currencyDecimals,
										currencyId: currencyDecimals,
										endDate: endDate,
										expectedInterest: expectedInterest,
										fixedPeriod: fixedPeriod,
										fixedPeriodType: fixedPeriodType,
										interestRate: interestRate,
										interestRateType: interestRateType,
										isDivested: isDivested,
										isMatured: isMatured,
										principalAmount: principalAmount,
										productId: productId,
										startDate: startDate,
										totalAmountPaidOut: totalAmountPaidOut,
										totalDepositCharge: totalDepositCharge,
										totalPenalties: totalPenalties,
										totalWithdrawalCharge: totalWithdrawalCharge,
										userId: userId,
										userRoleId: userRoleId,
										yearLengthInDays: yearLengthInDays,
										productInterestMode: productInterestMode,
										fixedDepositStatus: fixedDepositStatus,
										customerName: "#{userBioData.firstName} #{userBioData.lastName}"
									}
									fixedDeposit = Repo.insert!(fixedDeposit);


									carriedOutByUserId= userId
									carriedOutByUserRoleId= userRoleId
									isReversed= false
									orderRef= Integer.to_string(Enum.random(1_000000000..9_999999999))
									orderRef = "ZIPAKE#{orderRef}";
									productId= savingsProduct.id
									productType= "SAVINGS"
									referenceNo= Integer.to_string(Enum.random(1_000000000..9_999999999))
									requestData= nil
									responseData= nil
									status= "Success"
									totalAmount= amount
									transactionType= "CR"
									productCurrency= savingsProduct.currencyName


									currentBalance = calculateCurrentBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
									transactionDetail = "Deposit Payment for Fixed Deposit";
									transaction = %LoanSavingsSystem.Transactions.Transaction{
										accountId: accountId,
										carriedOutByUserId: carriedOutByUserId,
										carriedOutByUserRoleId: carriedOutByUserRoleId,
										isReversed: isReversed,
										orderRef: orderRef,
										productId: productId,
										productType: productType,
										referenceNo: referenceNo,
										requestData: requestData,
										responseData: responseData,
										status: status,
										totalAmount: totalAmount,
										transactionType: transactionType,
										userId: userId,
										userRoleId: userRoleId,
										transactionDetail: transactionDetail,
										transactionTypeEnum: "Deposit",
										newTotalBalance: (currentBalance),
										transactionTypeEnum: "Deposit",
										customerName: "#{userBioData.firstName} #{userBioData.lastName}",
										currencyDecimals: savingsProduct.currencyDecimals,
										currency: savingsProduct.currencyName
									};
									transaction = Repo.insert!(transaction);



									fixedDepositTransaction = %LoanSavingsSystem.FixedDeposit.FixedDepositTransaction{
										clientId: client.id,
										fixedDepositId: fixedDeposit.id,
										amountDeposited: principalAmount,
										transactionId: transaction.id,
										userId: userId,
										userRoleId: userRoleId,
										status: "SUCCESSFUL"
									};
									fixedDepositTransaction = Repo.insert!(fixedDepositTransaction);


									query = from au in LoanSavingsSystem.Accounts.Account,
										where: (au.userId == type(^userId, :integer) and au.userRoleId == type(^userRoleId, :integer)),
										select: au
									userAccounts = Repo.all(query);
									acc = Enum.at(userAccounts, 0);
									#acc = Repo.get!(LoanSavingsSystem.Accounts.Account, fixedDeposit.id)

									acct = LoanSavingsSystem.Accounts.Account.changesetForUpdate(acc,
									%{
										accountNo: acc.accountNo,
										accountType: acc.accountType,
										accountVersion: acc.accountVersion,
										clientId: acc.clientId,
										currencyDecimals: acc.currencyDecimals,
										currencyId: acc.currencyId,
										currencyName: acc.currencyName,
										status: acc.status,
										totalCharges: acc.totalCharges,
										totalDeposits: (acc.totalDeposits + principalAmount),
										totalInterestEarned: acc.totalInterestEarned,
										totalInterestPosted: acc.totalInterestPosted,
										totalPenalties: acc.totalPenalties,
										totalTax: acc.totalTax,
										totalWithdrawals: (acc.totalWithdrawals - principalAmount),
										userId: acc.userId,
										userRoleId: acc.userRoleId,
										DateClosed: nil,
										accountOfficerUserId: acc.accountOfficerId,
										blockedByUserId: acc.blockedByUserId,
										blockedReason: acc.blockedReason,
										deactivatedReason: acc.deactivatedReason,
										derivedAccountBalance: acc.derivedAccountBalance,
										externalId: acc.externalId
									})

									Repo.update!(acct)
									
									
									
									isWithdrawn = 
									if ((fd.principalAmount + fd.accruedInterest - (fd.totalAmountPaidOut + principalAmount))>0) do
										isWithdrawn = false
									else
										isWithdrawn = true;
									end
									
									
									cs = LoanSavingsSystem.FixedDeposit.FixedDeposits.changeset(fd,
										%{
											accountId: fd.accountId, productId: fd.productId, principalAmount: fd.principalAmount, fixedPeriod: fd.fixedPeriod, fixedPeriodType: fd.fixedPeriodType,
											interestRate: fd.interestRate, interestRateType: fd.interestRateType, expectedInterest: fd.expectedInterest, accruedInterest: fd.accruedInterest,
											isMatured: fd.isMatured, isDivested: fd.isDivested, divestmentPackageId: fd.divestmentPackageId, currencyId: fd.currencyId,
											currency: fd.currency, currencyDecimals: fd.currencyDecimals, yearLengthInDays: fd.yearLengthInDays, totalDepositCharge: fd.totalDepositCharge,
											totalWithdrawalCharge: fd.totalWithdrawalCharge, totalPenalties: fd.totalPenalties, userRoleId: fd.userRoleId, userId: fd.userId,
											totalAmountPaidOut: (fd.totalAmountPaidOut + principalAmount), startDate: fd.startDate, endDate: fd.endDate, clientId: fd.clientId, divestmentId: fd.divestmentId,
											productInterestMode: fd.productInterestMode, branchId: fd.branchId,
											divestedInterestRate: fd.divestedInterestRate, divestedInterestRateType: fd.fixedPeriodType,
											amountDivested: fd.amountDivested, divestedInterestAmount: fd.divestedInterestAmount, divestedPeriod: fd.divestedPeriod,
											fixedDepositStatus: fd.fixedDepositStatus, lastEndOfDayDate: fd.lastEndOfDayDate, isWithdrawn: isWithdrawn 
										})
									Repo.update!(cs)


									tempTotalAmount = Float.ceil(totalAmount, savingsProduct.currencyDecimals)
									tempTotalAmount = :erlang.float_to_binary((tempTotalAmount), [{:decimals, savingsProduct.currencyDecimals}])
									#tempTotalAmount = Float.to_string(tempTotalAmount)


									exInt = Float.ceil(fixedDeposit.expectedInterest, savingsProduct.currencyDecimals)
									exInt = :erlang.float_to_binary((exInt), [{:decimals, savingsProduct.currencyDecimals}])


									
									firstName = userBioData.firstName;


									naive_datetime = Timex.now
									sms = %{
										mobile: appUser.username,
										msg: "Dear #{firstName},\nYour deposit of #{productCurrency}" <> tempTotalAmount <> " has been recorded successfully. On confirmation, your deposit will been fixed for a period of #{fixedDeposit.fixedPeriod} #{fixedDeposit.fixedPeriodType} yielding you an interest of #{productCurrency}" <> exInt <> "\nOrder Ref: #{orderRef}",
										status: "READY",
										type: "SMS",
										msg_count: "1",
										date_sent: naive_datetime
									}
									Sms.changeset(%Sms{}, sms)
									|> Repo.insert()
									
									
									text = "Your deposit of #{productCurrency}" <> tempTotalAmount <> " has been posted. Your deposit has been fixed for a period of #{fixedDeposit.fixedPeriod} #{fixedDeposit.fixedPeriodType} yielding you an interest of #{productCurrency}" <> exInt <> "\nOrder Ref: #{orderRef}.\nPress \n\nb. Back \n0. End";
									response = text
									send_response(conn, response)

								else
									text = "The amount you provided to reinvest is more than what you currently have. Please enter a valid amount. Press \n\nb. Back \n0. End";
									response = text
									send_response(conn, response)
								end


								
							else
								text = "Invalid selection.Press \n\nb. Back \n0. End";
								response = text
								send_response(conn, response)
							end
						_ ->
							response = "Invalid selection. Press \n\nb. Back \n0. End"
							send_response(conn, response)
					end

                8 ->
					IO.inspect "########################";
					IO.inspect checkMenu
					parentIndex = Enum.at(checkMenu, 4)
					case parentIndex do
						"2" ->
							#For Partial Withdrawal
							keyEntered = Enum.at(checkMenu, 6)
							if keyEntered=="1" do
								selectedIndex = Enum.at(checkMenu, 3)
								selectedIndex = elem Integer.parse(selectedIndex), 0
								query = from au in User,
									where: (au.username == type(^mobile_number, :string)),
									select: au
								appUsers = Repo.all(query);
								appUser = Enum.at(appUsers, 0);

								individualRoleType = "INDIVIDUAL"
								query = from au in LoanSavingsSystem.Accounts.UserRole,
									where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
									select: au
								userRoles = Repo.all(query);
								userRole = Enum.at(userRoles, 0);
								userRoleId = userRole.id


								status = "Disbursed";
								isMatured = true
								isWithdrawn = false
								query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
									where: (au.isMatured == type(^isMatured, :boolean) and au.isWithdrawn == type(^isWithdrawn, :boolean) and au.userId >= type(^appUser.id, :integer)),
									select: au
								fixedDeposits = Repo.all(query);
								fixedDeposit = Enum.at(fixedDeposits, (selectedIndex-1));
								totalBalance = 0.00;


								productId = fixedDeposit.productId
								query = from au in LoanSavingsSystem.Products.Product,
									where: (au.id == type(^productId, :integer)) ,
									select: au
								savingsProducts = Repo.all(query)
								savingsProduct = Enum.at(savingsProducts, 0)


								amount = Enum.at(checkMenu, 5)
								amount = elem Float.parse(amount), 0
								Logger.info "<<<<<<"
								Logger.info amount



								totalRepayAmount = Float.ceil((fixedDeposit.principalAmount + fixedDeposit.accruedInterest), fixedDeposit.currencyDecimals)
								totalRepayAmount = :erlang.float_to_binary((totalRepayAmount), [{:decimals, fixedDeposit.currencyDecimals}])
								Logger.info "#{totalRepayAmount}"
								Logger.info "new valuation... #{totalRepayAmount}"


								reinvestPeriod = fixedDeposit.fixedPeriod
								balance = ((fixedDeposit.principalAmount + fixedDeposit.accruedInterest) - amount)
								reinvestCurrency = savingsProduct.currencyId



								query = from au in LoanSavingsSystem.Accounts.Account,
									where: (au.userRoleId == type(^userRole.id, :integer)),
									select: au
								accounts = Repo.all(query);
								account = Enum.at(accounts, 0);
								accountId = account.id
								userId = appUser.id

								carriedOutByUserId= userId
								carriedOutByUserRoleId= userRoleId
								isReversed= false
								orderRef= Integer.to_string(Enum.random(1_000000000..9_999999999))
								orderRef = "ZIPAKE#{orderRef}";
								withdrawalRef = orderRef;
								productId= savingsProduct.id
								productType= "SAVINGS"
								referenceNo= Integer.to_string(Enum.random(1_000000000..9_999999999))
								requestData= nil
								responseData= nil
								status= "Success"
								totalAmount= amount
								transactionType= "DR"
								productCurrency= savingsProduct.currencyName
								query = from au in LoanSavingsSystem.Client.UserBioData,
									where: (au.userId == type(^appUser.id, :integer)),
									select: au
								userBioData = Repo.one(query);


								currentBalance = calculateCurrentBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
								transactionDetail = "Withdrawal on Fixed Deposit Maturity";
								transaction = %LoanSavingsSystem.Transactions.Transaction{
									accountId: accountId,
									carriedOutByUserId: carriedOutByUserId,
									carriedOutByUserRoleId: carriedOutByUserRoleId,
									isReversed: isReversed,
									orderRef: orderRef,
									productId: productId,
									productType: productType,
									referenceNo: referenceNo,
									requestData: requestData,
									responseData: responseData,
									status: status,
									totalAmount: totalAmount,
									transactionType: transactionType,
									userId: userId,
									userRoleId: userRoleId,
									transactionDetail: transactionDetail,
									transactionTypeEnum: "Withdrawal",
									newTotalBalance: (currentBalance - totalAmount),
									customerName: "#{userBioData.firstName} #{userBioData.lastName}",
									currency: productCurrency,
									currencyDecimals: savingsProduct.currencyDecimals
								};
								transaction = Repo.insert!(transaction);


								maturedWithdrawals = %LoanSavingsSystem.Withdrawals.MaturedWithdrawal{
									clientId: client.id,
									amount: amount,
									fixedDepositId: fixedDeposit.id,
									fixedPeriod: fixedDeposit.fixedPeriod,
									interestRate: fixedDeposit.interestRate,
									interestRateType: fixedDeposit.interestRateType,
									principalAmount: fixedDeposit.principalAmount,
									interestAccrued: fixedDeposit.accruedInterest,
									userId: userId,
									userRoleId: userRoleId,
									transactionId: transaction.id
								};
								maturedWithdrawals = Repo.insert!(maturedWithdrawals);



								fd = Repo.get!(LoanSavingsSystem.FixedDeposit.FixedDeposits, fixedDeposit.id)
								cs = LoanSavingsSystem.FixedDeposit.FixedDeposits.changeset(fd,
									%{
										accountId: fd.accountId, productId: fd.productId, principalAmount: fd.principalAmount, fixedPeriod: fd.fixedPeriod, fixedPeriodType: fd.fixedPeriodType,
										interestRate: fd.interestRate, interestRateType: fd.interestRateType, expectedInterest: fd.expectedInterest, accruedInterest: fd.accruedInterest,
										isMatured: fd.isMatured, isDivested: fd.isDivested, divestmentPackageId: fd.divestmentPackageId, currencyId: fd.currencyId,
										currency: fd.currency, currencyDecimals: fd.currencyDecimals, yearLengthInDays: fd.yearLengthInDays, totalDepositCharge: fd.totalDepositCharge,
										totalWithdrawalCharge: fd.totalWithdrawalCharge, totalPenalties: fd.totalPenalties, userRoleId: fd.userRoleId, userId: fd.userId,
										totalAmountPaidOut: amount, startDate: fd.startDate, endDate: fd.endDate, clientId: fd.clientId, divestmentId: fd.divestmentId,
										productInterestMode: fd.productInterestMode, branchId: fd.branchId,
										divestedInterestRate: fd.divestedInterestRate, divestedInterestRateType: fd.divestedInterestRateType,
										amountDivested: fd.amountDivested, divestedInterestAmount: fd.divestedInterestAmount, divestedPeriod: fd.divestedPeriod, isWithdrawn: true
									})
								Repo.update!(cs)
								
								
								amtWithdrawnAndSentToAirtel = Decimal.round(Decimal.from_float(totalAmount), fixedDeposit.currencyDecimals)
								IO.inspect "CHECKER 1";
								
								
								
								url = "https://openapiuat.airtel.africa/auth/oauth2/token";
								xml = %{"client_id": "d3c57107-fd9a-4ea6-9aa1-461ac69384b0", "client_secret": "7ec36e58-d805-4076-9910-4a050328ce3c", "grant_type": "client_credentials"}
								IO.inspect "xml3"
								IO.inspect xml
								xml = Jason.encode!(xml);
								options = [];		
								#ssl: [{:versions, [:'tlsv3']}], recv_timeout: 5000
								header = [{"Content-Type", "application/json"}, {"Accept", "*/*"}];
								
								idLen1 = String.length("#{fixedDeposit.id}");
								fixedDepositNumber1 = String.pad_leading("#{fixedDeposit.id}", (6 - idLen1), "0");
								#logUssdRequest(appUser.id, "DIVEST FIXED DEPOSIT", nil, "SUCCESS", mobile_number, "Divested fixed deposit - ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{amtWithdrawnAndSentToAirtel}");
								
								

								case HTTPoison.request(:post, url, xml, [{"Content-Type", "application/json"}, {"Accept", "*/*"}]) do
									{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
										IO.inspect "000000000000000000"
										IO.inspect reason
										
										
										customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
											amount: amtWithdrawnAndSentToAirtel,
											fixedDepositId: fixedDeposit.id,
											orderRef: orderRef,
											payoutRequest: xml,
											payoutResponse: "#{reason}",
											payoutType: "WITHDRAWAL",
											status: "FAILED",
											transactionDate: Date.utc_today,
											transactionId: transaction.id,
											userId: appUser.id
										}
										customerPayout = Repo.insert!(customerPayout);
										logUssdRequest(appUser.id, "TRANSFER TO CUSTOMER", nil, "FAILED", mobile_number, "Transfer Divestment Queued- #{userBioData.firstName} #{userBioData.lastName} | ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{(amtWithdrawnAndSentToAirtel)}");
									{:ok, struct} ->
										IO.inspect struct.body
										bearerBody =  Jason.decode!(struct.body)
										IO.inspect bearerBody
										bearer = bearerBody["access_token"]
										IO.inspect bearer
										
										encryptedPin = "";
										encryptedPin = rsaEncryptDataForAirtel("0000")
										IO.inspect encryptedPin
										mobileNumberTruncated = "";
										mobileNumber = appUser.username;
										IO.inspect mobileNumber;
										mobileNumberTruncated = String.slice(mobileNumber, 3..11);
										
										url = "https://openapiuat.airtel.africa/standard/v1/disbursements/"
										xml = %{"payee": %{"msisdn": "#{mobileNumberTruncated}"}, "reference": "#{orderRef}", "pin": encryptedPin, "transaction": %{"amount": (amtWithdrawnAndSentToAirtel), "id": "#{orderRef}"}}
										xml = Jason.encode!(xml);
										IO.inspect xml
										case HTTPoison.request(:post, url, xml, [{"Content-Type", "application/json"}, {"Accept", "*/*"}, {"X-Country", "ZM"}, {"X-Currency", "ZMW"}, {"Authorization", "Bearer #{bearer}"}]) do
											{:error, %HTTPoison.Error{id: nil, reason: reason}} ->
												IO.inspect "000000000000000000"
												IO.inspect reason
												customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
													amount: (amtWithdrawnAndSentToAirtel),
													fixedDepositId: fixedDeposit.id,
													orderRef: orderRef,
													payoutRequest: xml,
													payoutResponse: "#{reason}",
													payoutType: "WITHDRAWAL",
													status: "FAILED",
													transactionDate: Date.utc_today,
													transactionId: transaction.id,
													userId: appUser.id
												}
												customerPayout = Repo.insert!(customerPayout);
												logUssdRequest(appUser.id, "TRANSFER TO CUSTOMER", nil, "FAILED", mobile_number, "Transfer Divestment Queued- #{userBioData.firstName} #{userBioData.lastName} | ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{(amtWithdrawnAndSentToAirtel)}");
											{:ok, struct} ->
												IO.inspect struct.body
												body = struct.body;
												body = Jason.decode!(body)
												status = body['status']['success']
												if(status==true) do
													status = String.downcase(status, :default);
													customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
														amount: amtWithdrawnAndSentToAirtel,
														fixedDepositId: fixedDeposit.id,
														orderRef: orderRef,
														payoutRequest: xml,
														payoutResponse: (body['status']['message']),
														payoutType: "WITHDRAWAL",
														status: status,
														transactionDate: Date.utc_today,
														transactionId: transaction.id,
														userId: appUser.id
													}
													customerPayout = Repo.insert!(customerPayout);
													logUssdRequest(appUser.id, "TRANSFER TO CUSTOMER", nil, "SUCCESS", mobile_number, "Transfer Divestment Sent - #{userBioData.firstName} #{userBioData.lastName} | ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{(amtWithdrawnAndSentToAirtel)}");
												else
													customerPayout = %LoanSavingsSystem.CustomerPayouts.CustomerPayout{
														amount: amtWithdrawnAndSentToAirtel,
														fixedDepositId: fixedDeposit.id,
														orderRef: orderRef,
														payoutRequest: xml,
														payoutResponse: (body['status']['message']),
														payoutType: "WITHDRAWAL",
														status: status,
														transactionDate: Date.utc_today,
														transactionId: transaction.id,
														userId: appUser.id
													}
													customerPayout = Repo.insert!(customerPayout);
													logUssdRequest(appUser.id, "TRANSFER TO CUSTOMER", nil, "FAILED", mobile_number, "Transfer Divestment Queued- #{userBioData.firstName} #{userBioData.lastName} | ##{fixedDepositNumber1} | #{fixedDeposit.currency}#{(amtWithdrawnAndSentToAirtel)}");
												end
												
										end
								end
								
								
								
								

								if balance>0 do
									query = from au in LoanSavingsSystem.Products.Product,
										where: (au.minimumPrincipal <= type(^balance, :float) and au.status == "ACTIVE" and au.maximumPrincipal >= type(^balance, :float) and au.defaultPeriod == type(^reinvestPeriod, :integer) and au.currencyId == type(^reinvestCurrency, :integer)) ,
										select: au
									reinvestSavingsProducts = Repo.all(query)
									reinvestSavingsProduct = Enum.at(reinvestSavingsProducts, 0)
									reinvestValuationCurrency = reinvestSavingsProduct.currencyName
									reinvestPeriod = reinvestSavingsProduct.defaultPeriod
									reinvestPeriodType = reinvestSavingsProduct.periodType


									reinvestValuation = calculate_maturity_repayments(balance, reinvestPeriod,
										  reinvestSavingsProduct.interest, reinvestSavingsProduct.yearLengthInDays, reinvestSavingsProduct.interestMode,
										  reinvestSavingsProduct.interestType, reinvestSavingsProduct.periodType)
									reinvestValuation = Float.ceil(reinvestValuation, reinvestSavingsProduct.currencyDecimals)


									carriedOutByUserId= userId
									carriedOutByUserRoleId= userRoleId
									isReversed= false
									orderRef= Integer.to_string(Enum.random(1_000000000..9_999999999))
									orderRef = "ZIPAKE#{orderRef}";
									productId= reinvestSavingsProduct.id
									productType= "SAVINGS"
									referenceNo= Integer.to_string(Enum.random(1_000000000..9_999999999))
									requestData= nil
									responseData= nil
									status= "Success"
									totalAmount= balance
									transactionType= "CR"
									productCurrency= reinvestSavingsProduct.currencyName


									transactionDetail = "Fixed Deposit on Balance";
									currentBalance = calculateCurrentBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
									transaction = %LoanSavingsSystem.Transactions.Transaction{
										accountId: accountId,
										carriedOutByUserId: carriedOutByUserId,
										carriedOutByUserRoleId: carriedOutByUserRoleId,
										isReversed: isReversed,
										orderRef: orderRef,
										productId: productId,
										productType: productType,
										referenceNo: referenceNo,
										requestData: requestData,
										responseData: responseData,
										status: status,
										totalAmount: totalAmount,
										transactionType: transactionType,
										userId: userId,
										userRoleId: userRoleId,
										transactionDetail: transactionDetail,
										newTotalBalance: (currentBalance + totalAmount),
										transactionTypeEnum: "Deposit",
										customerName: "#{userBioData.firstName} #{userBioData.lastName}",
										currencyDecimals: reinvestSavingsProduct.currencyDecimals,
										currency: reinvestSavingsProduct.currencyName
									};
									transaction = Repo.insert!(transaction);


									expectedInterest= Float.ceil((reinvestValuation - balance), reinvestSavingsProduct.currencyDecimals)
									fixedPeriod= reinvestSavingsProduct.defaultPeriod
									fixedPeriodType= reinvestSavingsProduct.periodType
									interestRate= reinvestSavingsProduct.interest
									interestRateType= reinvestSavingsProduct.interestType
									isDivested= false
									isMatured= false
									isWithdrawn = false
									principalAmount= balance
									productId= reinvestSavingsProduct.id
									startDate= fd.startDate
									totalAmountPaidOut= 0.00
									totalDepositCharge= 0.00
									totalPenalties= 0.00
									totalWithdrawalCharge= 0.00
									yearLengthInDays= reinvestSavingsProduct.yearLengthInDays
									accruedInterest = 0.00
									currencyId = reinvestSavingsProduct.currencyId
									currencyDecimals = reinvestSavingsProduct.currencyDecimals
									currency = reinvestSavingsProduct.currencyName
									endDate = fd.endDate
									fixedDepositStatus = "ACTIVE"


									fixedDeposit = %LoanSavingsSystem.FixedDeposit.FixedDeposits{
										accountId: accountId,
										accruedInterest: accruedInterest,
										clientId: client.id,
										currency: currency,
										currencyDecimals: currencyDecimals,
										currencyId: currencyDecimals,
										endDate: endDate,
										expectedInterest: expectedInterest,
										fixedPeriod: fixedPeriod,
										fixedPeriodType: fixedPeriodType,
										interestRate: interestRate,
										interestRateType: interestRateType,
										isDivested: isDivested,
										isMatured: isMatured,
										isWithdrawn: isWithdrawn,
										principalAmount: principalAmount,
										productId: productId,
										startDate: startDate,
										totalAmountPaidOut: totalAmountPaidOut,
										totalDepositCharge: totalDepositCharge,
										totalPenalties: totalPenalties,
										totalWithdrawalCharge: totalWithdrawalCharge,
										userId: userId,
										userRoleId: userRoleId,
										yearLengthInDays: yearLengthInDays,
										fixedDepositStatus: fixedDepositStatus,
										customerName: "#{userBioData.firstName} #{userBioData.lastName}"
									}
									fixedDeposit = Repo.insert!(fixedDeposit);


									fixedDepositTransaction = %LoanSavingsSystem.FixedDeposit.FixedDepositTransaction{
										clientId: client.id,
										fixedDepositId: fixedDeposit.id,
										amountDeposited: principalAmount,
										transactionId: transaction.id,
										userId: userId,
										userRoleId: userRoleId,
										status: "SUCCESSFUL"
									};
									fixedDepositTransaction = Repo.insert!(fixedDepositTransaction);

									amountStr = :erlang.float_to_binary((amount), [{:decimals, savingsProduct.currencyDecimals}])
									balance = :erlang.float_to_binary((balance), [{:decimals, reinvestSavingsProduct.currencyDecimals}])
									msg = "The sum of #{fixedDeposit.currency}#{amountStr} has been paid into your Airtel mobile money account.\n\nThe balance of #{reinvestValuationCurrency}#{balance} has also been fixed for #{reinvestPeriod}  #{reinvestPeriodType} to yield you #{reinvestValuationCurrency}#{reinvestValuation}\n\nb. Back\n0. End"



									query = from au in LoanSavingsSystem.Client.UserBioData,
										where: (au.userId == type(^userId, :integer)),
										select: au
									userBioData = Repo.one(query);
									firstName = userBioData.firstName;


									naive_datetime = Timex.now
									sms = %{
										mobile: appUser.username,
										msg: "Dear #{firstName},\nYour withdrawal of #{fixedDeposit.currency}#{amountStr} was paid into your Airtel mobile money account.\nOrder Ref: #{withdrawalRef}",
										status: "READY",
										type: "SMS",
										msg_count: "1",
										date_sent: naive_datetime
									}
									Sms.changeset(%Sms{}, sms)
									|> Repo.insert()


									naive_datetime = Timex.now
									sms = %{
										mobile: appUser.username,
										msg: "Dear #{firstName},\nThe balance of #{reinvestValuationCurrency}#{balance} has been fixed for #{reinvestPeriod}  #{reinvestPeriodType} to yield you #{reinvestValuationCurrency}#{reinvestValuation}.\nOrder Ref: #{orderRef}",
										status: "READY",
										type: "SMS",
										msg_count: "1",
										date_sent: naive_datetime
									}
									Sms.changeset(%Sms{}, sms)
									|> Repo.insert()

									#response = %{
									#    Message: msg,
									#    ClientState: 2,
									#    Type: "Response",
									#    key: "CON"
									#}
									response = msg
									send_response(conn, response)
								else
									newValuation = :erlang.float_to_binary((amount), [{:decimals, savingsProduct.currencyDecimals}])
									msg = "The sum of #{fixedDeposit.currency}#{newValuation} has been paid into your mobile money account. Thanks\n\n\nb. Back\n0. End"

									#response = %{
									#    Message: msg,
									#    ClientState: 2,
									#    Type: "Response",
									#    key: "CON"
									#}

									query = from au in LoanSavingsSystem.Client.UserBioData,
										where: (au.userId == type(^userId, :integer)),
										select: au
									userBioData = Repo.one(query);
									firstName = userBioData.firstName;

									naive_datetime = Timex.now
									sms = %{
										mobile: appUser.username,
										msg: "Dear #{firstName}, Your withdrawal of #{fixedDeposit.currency}#{newValuation} was paid into your Airtel mobile money account.\nOrder Ref: #{withdrawalRef}",
										status: "READY",
										type: "SMS",
										msg_count: "1",
										date_sent: naive_datetime
									}
									Sms.changeset(%Sms{}, sms)
									|> Repo.insert()


									response = msg
									send_response(conn, response)
								end



							else

								#response = %{
								#    Message: "Invalid selection.. Press\n\nb. Back\n0. Log Out",
								#    ClientState: 1,
								#    Type: "Response",
								#    key: "BA3"
								#}
								response = "Invalid selection.. Press\n\nb. Back\n0. Log Out"
								send_response(conn, response)
							end
						"3" ->
							isMatured = true;
							isWithdrawn = false;
							query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
								where: (au.isMatured == type(^isMatured, :boolean) and au.isWithdrawn == type(^isWithdrawn, :boolean) and au.userId >= type(^appUser.id, :integer)),
								select: au
							fixedDeposits = Repo.all(query);
							totalBalance = 0.00;

								Logger.info "=========="
								Logger.info Enum.count(fixedDeposits)

							if (Enum.count(fixedDeposits)>0) do
							
								selectedFdIndex = Enum.at(checkMenu, 3)
								Logger.info selectedFdIndex
								selectedFdIndex = elem Integer.parse(selectedFdIndex), 0



								
								fixedDeposit = Enum.at(fixedDeposits, (selectedFdIndex-1));


								fd = Repo.get!(LoanSavingsSystem.FixedDeposit.FixedDeposits, fixedDeposit.id)
								totalDueAtMaturity = fd.principalAmount + fd.accruedInterest - fd.totalAmountPaidOut;
								amount = Enum.at(checkMenu, 5)
								amount = elem Float.parse(amount), 0
								if(amount>0 && amount<=totalDueAtMaturity) do
								
									Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
									selectedIndex = Enum.at(checkMenu, 4)
									Logger.info "selectedIndex..."
									Logger.info selectedIndex
									selectedIndex = elem Integer.parse(selectedIndex), 0
									Logger.info selectedIndex
									query = from au in LoanSavingsSystem.Products.Product,
										where: (au.id == type(^fd.productId, :integer)) ,
										select: au
									savingsProduct = Repo.one(query)

									default_rate = savingsProduct.interest
									default_period = savingsProduct.defaultPeriod
									annual_period = savingsProduct.yearLengthInDays
									#amt = elem Integer.parse(amount), 0
									amt = amount


									totalRepayments = calculate_maturity_repayments(amt, default_period, default_rate, annual_period, savingsProduct.interestMode, savingsProduct.interestType, savingsProduct.periodType)
									Logger.info "Test";
									Logger.info ((totalRepayments));

									#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [decimals= savingsProduct.currencyDecimals])
									totalRepayAmount = Float.ceil(totalRepayments, savingsProduct.currencyDecimals)
									#totalRepayAmount = :erlang.float_to_binary((totalRepayments), [{decimals, savingsProduct.currencyDecimals}])
									totalRepayAmount = Float.to_string(totalRepayAmount)
									Logger.info "#{totalRepayAmount}"
									default_period = :erlang.integer_to_binary(default_period)
									repay_entry = default_period <> " " <> savingsProduct.periodType <> " gives you " <> savingsProduct.currencyName <> totalRepayAmount <> "  "
									Logger.info "#{totalRepayAmount}"
									Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"

									query = from au in LoanSavingsSystem.Accounts.User,
										where: (au.username == type(^mobile_number, :string)),
										select: au
									appUsers = Repo.all(query);
									appUser = Enum.at(appUsers, 0);

									individualRoleType = "INDIVIDUAL"
									query = from au in LoanSavingsSystem.Accounts.UserRole,
										where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
										select: au
									appUserRoles = Repo.all(query);
									appUserRole = Enum.at(appUserRoles, 0);

									Logger.info "Twst ........";
									Logger.info savingsProduct.id;
									totalCharges = 0.00;

									totalCharge = 0.00;


									query = from au in LoanSavingsSystem.Accounts.Account,
										where: (au.userRoleId == type(^appUserRole.id, :integer)),
										select: au
									accounts = Repo.all(query);
									account = Enum.at(accounts, 0);
									accountId = account.id

									accruedInterest= 0.00
									clientId= client.id
									currency= savingsProduct.currencyName
									currencyDecimals= savingsProduct.currencyDecimals
									currencyId= savingsProduct.currencyId

											Logger.info "%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
											Logger.info savingsProduct.defaultPeriod

									endDate = case savingsProduct.periodType do
										"Days" ->
											endDate = DateTime.add(DateTime.utc_now, (24*60*60*savingsProduct.defaultPeriod), :second) |> DateTime.truncate(:second)
											endDate
										"Months" ->
											endDate = DateTime.add(DateTime.utc_now, (24*60*60*savingsProduct.defaultPeriod*30), :second) |> DateTime.truncate(:second)
											endDate
										"Years" ->
											endDate = DateTime.add(DateTime.utc_now, (24*60*60*savingsProduct.defaultPeriod*savingsProduct.yearLengthInDays), :second) |> DateTime.truncate(:second)
											endDate
									end


									expectedInterest= Float.ceil((totalRepayments - amount), savingsProduct.currencyDecimals)
									fixedPeriod= savingsProduct.defaultPeriod
									fixedPeriodType= savingsProduct.periodType
									interestRate= savingsProduct.interest
									interestRateType= savingsProduct.interestType
									productInterestMode= savingsProduct.interestMode
									isDivested= false
									isMatured= false
									principalAmount= amount
									productId= savingsProduct.id
									startDate= DateTime.utc_now |> DateTime.truncate(:second)
									totalAmountPaidOut= 0.00
									totalDepositCharge= totalCharge
									totalPenalties= 0.00
									totalWithdrawalCharge= 0.00
									userId= appUser.id
									userRoleId= appUserRole.id
									yearLengthInDays= savingsProduct.yearLengthInDays
									fixedDepositStatus = "ACTIVE";
									userId= appUser.id
									query = from au in LoanSavingsSystem.Client.UserBioData,
										where: (au.userId == type(^userId, :integer)),
										select: au
									userBioData = Repo.one(query);

									fixedDeposit = %LoanSavingsSystem.FixedDeposit.FixedDeposits{
										accountId: accountId,
										accruedInterest: accruedInterest,
										clientId: clientId,
										currency: currency,
										currencyDecimals: currencyDecimals,
										currencyId: currencyDecimals,
										endDate: endDate,
										expectedInterest: expectedInterest,
										fixedPeriod: fixedPeriod,
										fixedPeriodType: fixedPeriodType,
										interestRate: interestRate,
										interestRateType: interestRateType,
										isDivested: isDivested,
										isMatured: isMatured,
										principalAmount: principalAmount,
										productId: productId,
										startDate: startDate,
										totalAmountPaidOut: totalAmountPaidOut,
										totalDepositCharge: totalDepositCharge,
										totalPenalties: totalPenalties,
										totalWithdrawalCharge: totalWithdrawalCharge,
										userId: userId,
										userRoleId: userRoleId,
										yearLengthInDays: yearLengthInDays,
										productInterestMode: productInterestMode,
										fixedDepositStatus: fixedDepositStatus,
										customerName: "#{userBioData.firstName} #{userBioData.lastName}"
									}
									fixedDeposit = Repo.insert!(fixedDeposit);


									carriedOutByUserId= userId
									carriedOutByUserRoleId= userRoleId
									isReversed= false
									orderRef= Integer.to_string(Enum.random(1_000000000..9_999999999))
									orderRef = "ZIPAKE#{orderRef}";
									productId= savingsProduct.id
									productType= "SAVINGS"
									referenceNo= Integer.to_string(Enum.random(1_000000000..9_999999999))
									requestData= nil
									responseData= nil
									status= "Success"
									totalAmount= amount
									transactionType= "CR"
									productCurrency= savingsProduct.currencyName
									transactionTypeEnum = "";


									currentBalance = calculateCurrentBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
									transactionDetail = "Deposit Payment for Fixed Deposit";
									transaction = %LoanSavingsSystem.Transactions.Transaction{
										accountId: accountId,
										carriedOutByUserId: carriedOutByUserId,
										carriedOutByUserRoleId: carriedOutByUserRoleId,
										isReversed: isReversed,
										orderRef: orderRef,
										productId: productId,
										productType: productType,
										referenceNo: referenceNo,
										requestData: requestData,
										responseData: responseData,
										status: status,
										totalAmount: totalAmount,
										transactionType: transactionType,
										userId: userId,
										userRoleId: userRoleId,
										transactionDetail: transactionDetail,
										transactionTypeEnum: "Deposit",
										newTotalBalance: (currentBalance),
										customerName: "#{userBioData.firstName} #{userBioData.lastName}",
										currencyDecimals: fixedDeposit.currencyDecimals,
										currency: fixedDeposit.currency
									};
									transaction = Repo.insert!(transaction);



									fixedDepositTransaction = %LoanSavingsSystem.FixedDeposit.FixedDepositTransaction{
										clientId: client.id,
										fixedDepositId: fixedDeposit.id,
										amountDeposited: principalAmount,
										transactionId: transaction.id,
										userId: userId,
										userRoleId: userRoleId,
										status: "SUCCESSFUL"
									};
									fixedDepositTransaction = Repo.insert!(fixedDepositTransaction);


									query = from au in LoanSavingsSystem.Accounts.Account,
										where: (au.userId == type(^userId, :integer) and au.userRoleId == type(^userRoleId, :integer)),
										select: au
									userAccounts = Repo.all(query);
									acc = Enum.at(userAccounts, 0);
									#acc = Repo.get!(LoanSavingsSystem.Accounts.Account, fixedDeposit.id)

									acct = LoanSavingsSystem.Accounts.Account.changesetForUpdate(acc,
									%{
										accountNo: acc.accountNo,
										accountType: acc.accountType,
										accountVersion: acc.accountVersion,
										clientId: acc.clientId,
										currencyDecimals: acc.currencyDecimals,
										currencyId: acc.currencyId,
										currencyName: acc.currencyName,
										status: acc.status,
										totalCharges: acc.totalCharges,
										totalDeposits: (acc.totalDeposits + principalAmount),
										totalInterestEarned: acc.totalInterestEarned,
										totalInterestPosted: acc.totalInterestPosted,
										totalPenalties: acc.totalPenalties,
										totalTax: acc.totalTax,
										totalWithdrawals: (acc.totalWithdrawals - principalAmount),
										userId: acc.userId,
										userRoleId: acc.userRoleId,
										DateClosed: nil,
										accountOfficerUserId: acc.accountOfficerId,
										blockedByUserId: acc.blockedByUserId,
										blockedReason: acc.blockedReason,
										deactivatedReason: acc.deactivatedReason,
										derivedAccountBalance: acc.derivedAccountBalance,
										externalId: acc.externalId
									})

									Repo.update!(acct)
									
									
									
									isWithdrawn = 
									if ((fd.principalAmount + fd.accruedInterest - (fd.totalAmountPaidOut + principalAmount))>0) do
										isWithdrawn = false
									else
										isWithdrawn = true;
									end
									
									fdId = fd.id;
									
									cs = LoanSavingsSystem.FixedDeposit.FixedDeposits.changeset(fd,
										%{
											accountId: fd.accountId, productId: fd.productId, principalAmount: fd.principalAmount, fixedPeriod: fd.fixedPeriod, fixedPeriodType: fd.fixedPeriodType,
											interestRate: fd.interestRate, interestRateType: fd.interestRateType, expectedInterest: fd.expectedInterest, accruedInterest: fd.accruedInterest,
											isMatured: fd.isMatured, isDivested: fd.isDivested, divestmentPackageId: fd.divestmentPackageId, currencyId: fd.currencyId,
											currency: fd.currency, currencyDecimals: fd.currencyDecimals, yearLengthInDays: fd.yearLengthInDays, totalDepositCharge: fd.totalDepositCharge,
											totalWithdrawalCharge: fd.totalWithdrawalCharge, totalPenalties: fd.totalPenalties, userRoleId: fd.userRoleId, userId: fd.userId,
											totalAmountPaidOut: (fd.totalAmountPaidOut + principalAmount), startDate: fd.startDate, endDate: fd.endDate, clientId: fd.clientId, divestmentId: fd.divestmentId,
											productInterestMode: fd.productInterestMode, branchId: fd.branchId,
											divestedInterestRate: fd.divestedInterestRate, divestedInterestRateType: fd.fixedPeriodType,
											amountDivested: fd.amountDivested, divestedInterestAmount: fd.divestedInterestAmount, divestedPeriod: fd.divestedPeriod,
											fixedDepositStatus: fd.fixedDepositStatus, lastEndOfDayDate: fd.lastEndOfDayDate, isWithdrawn: isWithdrawn 
										})
									Repo.update!(cs)
									
									
									
									


									tempTotalAmount = Float.ceil(totalAmount, savingsProduct.currencyDecimals)
									tempTotalAmount = :erlang.float_to_binary((tempTotalAmount), [{:decimals, savingsProduct.currencyDecimals}])
									#tempTotalAmount = Float.to_string(tempTotalAmount)


									exInt = Float.ceil(fixedDeposit.expectedInterest, savingsProduct.currencyDecimals)
									exInt = :erlang.float_to_binary((exInt), [{:decimals, savingsProduct.currencyDecimals}])


									
									firstName = userBioData.firstName;


									naive_datetime = Timex.now
									sms = %{
										mobile: appUser.username,
										msg: "Dear #{firstName},\nYour deposit of #{productCurrency}" <> tempTotalAmount <> " has been recorded successfully. On confirmation, your deposit will been fixed for a period of #{fixedDeposit.fixedPeriod} #{fixedDeposit.fixedPeriodType} yielding you an interest of #{productCurrency}" <> exInt <> "\nOrder Ref: #{orderRef}",
										status: "READY",
										type: "SMS",
										msg_count: "1",
										date_sent: naive_datetime
									}
									Sms.changeset(%Sms{}, sms)
									|> Repo.insert()
									
									
									text = "Your deposit of #{productCurrency}" <> tempTotalAmount <> " has been posted. Your deposit has been fixed for a period of #{fixedDeposit.fixedPeriod} #{fixedDeposit.fixedPeriodType} yielding you an interest of #{productCurrency}" <> exInt <> "\nOrder Ref: #{orderRef}.\nPress \n\nb. Back \n0. End";
									response = text
									send_response(conn, response)

								else
									text = "The amount you provided to reinvest is more than what you currently have. Please enter a valid amount. Press \n\nb. Back \n0. End";
									response = text
									send_response(conn, response)
								end


								
							else
								text = "Invalid selection.Press \n\nb. Back \n0. End";
								response = text
								send_response(conn, response)
							end
					end	
            end
        end
    end




	def handleReinvestSomeMaturedFunds(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, appUser) do
		checkMenuLength = Enum.count(checkMenu)
		defaultCurrency = client.defaultCurrencyId
		valueEntered = Enum.at(checkMenu, (checkMenuLength-1))
		Logger.info("handleGetLoan");
		Logger.info(checkMenuLength);
		Logger.info(valueEntered);
		Logger.info(text);
		if valueEntered == "b" do
			#response = %{
			#    Message: "BA3",
			#    ClientState: 1,
			#    Type: "Response",
			#    key: "BA3"
			#}

			response = "BA3"
			send_response(conn, response)
		else
			case checkMenuLength do
				6 ->
					response = "Enter how much you are reinvesting?"
					send_response(conn, response)
			end
		end
	end




	def handleReinvestAllMaturedFunds(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, appUser) do	
		selectedIndex = Enum.at(checkMenu, 3)
		selectedIndex = elem Integer.parse(selectedIndex), 0
		query = from au in User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUsers = Repo.all(query);
		appUser = Enum.at(appUsers, 0);

		individualRoleType = "INDIVIDUAL"
		query = from au in LoanSavingsSystem.Accounts.UserRole,
			where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
			select: au
		userRoles = Repo.all(query);
		userRole = Enum.at(userRoles, 0);


		status = "Disbursed";
		isMatured = true
		isWithdrawn = false
		query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
			where: (au.isMatured == type(^isMatured, :boolean) and au.isWithdrawn == type(^isWithdrawn, :boolean) and au.userId >= type(^appUser.id, :integer)),
			select: au
		fixedDeposits = Repo.all(query);
		fixedDeposit = Enum.at(fixedDeposits, (selectedIndex-1));
		totalBalance = 0.00;


		productId = fixedDeposit.productId
		query = from au in LoanSavingsSystem.Products.Product,
			where: (au.id == type(^productId, :integer)) ,
			select: au
		savingsProducts = Repo.all(query)
		savingsProduct = Enum.at(savingsProducts, 0)


		amount = fixedDeposit.principalAmount + fixedDeposit.accruedInterest - fixedDeposit.totalAmountPaidOut
		Logger.info "<<<<<<"
		Logger.info amount



		newValuation = :erlang.float_to_binary((fixedDeposit.principalAmount + fixedDeposit.accruedInterest), [{:decimals, savingsProduct.currencyDecimals}])
		amountStr = :erlang.float_to_binary((amount), [{:decimals, savingsProduct.currencyDecimals}])

		Logger.info "#{newValuation}"
		Logger.info "new valuation... #{newValuation}"


		reinvestPeriod = fixedDeposit.fixedPeriod
		balance = amount
		reinvestCurrency = savingsProduct.currencyId
		reinvestCurrencyName = savingsProduct.currencyName


		if balance>0 do
			query = from au in LoanSavingsSystem.Products.Product,
				where: (au.id  == type(^fixedDeposit.productId, :integer)) ,
				select: au
			reinvestSavingsProduct = Repo.one(query)
			
			reinvestValuationCurrency = reinvestSavingsProduct.currencyName
			reinvestPeriod = reinvestSavingsProduct.defaultPeriod
			reinvestPeriodType = reinvestSavingsProduct.periodType
			reinvestEndDate = case reinvestSavingsProduct.periodType do
				"Days" ->
					endDate = DateTime.add(DateTime.utc_now, (24*60*60*reinvestSavingsProduct.defaultPeriod), :second) |> DateTime.truncate(:second)
					endDate
				"Months" ->
					endDate = DateTime.add(DateTime.utc_now, (24*60*60*reinvestSavingsProduct.defaultPeriod*30), :second) |> DateTime.truncate(:second)
					endDate
				"Years" ->
					endDate = DateTime.add(DateTime.utc_now, (24*60*60*reinvestSavingsProduct.defaultPeriod*reinvestSavingsProduct.yearLengthInDays), :second) |> DateTime.truncate(:second)
					endDate
			end

			reinvestValuation = calculate_maturity_repayments(balance, reinvestPeriod,
				reinvestSavingsProduct.interest, reinvestSavingsProduct.yearLengthInDays, reinvestSavingsProduct.interestMode,
				reinvestSavingsProduct.interestType, reinvestSavingsProduct.periodType)
			reinvestValuation = Float.ceil(reinvestValuation, reinvestSavingsProduct.currencyDecimals)
			reinvestValuation = :erlang.float_to_binary((reinvestValuation), [{:decimals, reinvestSavingsProduct.currencyDecimals}])

			reinvestEndDate = String.slice("#{reinvestEndDate}", 0, 10);
			msg = "If you reinvest #{reinvestCurrencyName}#{amountStr}, we will give you #{reinvestValuationCurrency}#{reinvestValuation} on #{reinvestEndDate} \n\n1. Confirm\nb. Back"

			#response = %{
			#    Message: msg,
			#    ClientState: 2,
			#    Type: "Response",
			#    key: "CON"
			#}

			response = msg
			send_response(conn, response)
		else
			if balance<0 do
				msg = "Invalid amount. Please try again";
				msg = msg <> "\n\n1. Confirm\nb. Back"

				#response = %{
				#    Message: msg,
				#    ClientState: 2,
				#    Type: "Response",
				#    key: "CON"
				#}

				response = msg
				send_response(conn, response)
			else
				msg = "If you withdraw today you will receive #{fixedDeposit.currency}#{amountStr}";
				msg = msg <> "\n\n1. Confirm\nb. Back"

				#response = %{
				#    Message: msg,
				#    ClientState: 2,
				#    Type: "Response",
				#    key: "CON"
				#}

				response = msg
				send_response(conn, response)
			end
		end
	end

    def calculate_maturity_repayments(amount, period, rate, annual_period, interestMode, interestType, periodType) do
        Logger.info "################"
        Logger.info amount
        #Logger.info period
        #Logger.info "Rate ...#{rate}"
        #Logger.info annual_period
        Logger.info interestType
        Logger.info interestMode
        Logger.info periodType
        Logger.info annual_period

        rate = case interestType do
            "Days" ->
                rate = rate * annual_period
                rate = rate/100
                rate = rate/annual_period
                rate
            "Months" ->
                rate = rate*12
                rate = rate/100
                rate = rate/annual_period
                rate
            "Year" ->
                rate = rate/100
                Logger.info rate
                rate = rate/annual_period
                Logger.info rate
                rate
        end

        Logger.info "+++++++++++++++++"
        Logger.info rate

        totalRepayable = 0.00;
        y = 1;

        case interestMode do
            "FLAT" ->
                incurredInterest = amount * rate * period
                Logger.info "#{amount} * #{rate} * #{period} * "
                Logger.info incurredInterest
                totalPayableAtEnd = incurredInterest + amount;
                totalPayableAtEnd
            "COMPOUND INTEREST" ->
                rate__ = (1+rate);
                number_of_repayments = 1
                raisedVal = :math.pow(rate__, (number_of_repayments))
                Logger.info raisedVal
                a = rate*raisedVal
                b = raisedVal - 1
                c = a/b
                totalPayableInMonthX = amount * ((rate*(raisedVal))/(raisedVal - 1));
                Logger.info totalPayableInMonthX
                #realMonthlyRepayment = amount * (rate) * (1)
                totalPayableInMonthX
        end
    end



    def welcome_menu(conn, mobile_number, cmd, text, client, clientTelco) do
        Logger.info "Welcome menu ======================"
        Logger.info text
        orginal_short_code = cmd
        clientName = client.clientName


        query = from au in LoanSavingsSystem.Accounts.User, where: au.username == ^mobile_number, select: au
        users = Repo.all(query)
        user = Enum.at(users, 0)

        userId = user.id
        query = from au in LoanSavingsSystem.Accounts.UserRole, where: (au.userId == ^userId and au.roleType == "INDIVIDUAL"), select: au
        customers = Repo.all(query)

        query = from pd in Product, select: pd
        products = Repo.all(query)


        Logger.info "customers count"
        Logger.info Enum.count(customers)
        Logger.info "customers count"
        Logger.info "Products count..."
        Logger.info Enum.count(products)
        Logger.info client.id





        if (Enum.count(customers)>0) do

            checkMenu = String.split(text, "\*")
            checkMenuLength = Enum.count(checkMenu)
            Logger.info(checkMenuLength)

            if checkMenuLength==3 do
                #response = %{
                #    Message: "Welome to #{clientName}\n\n1. Make Deposit of choice\n2. Check Balance\n3. SMS Statement\n4. Divest\n5. Change Pin\n6. Terms and Conditions\n0. End",
                #    ClientState: 1,
                #    Type: "Response",
                #    key: "CON"
                #}

				
				response = "Welcome to #{clientName}\n\n1. Make Deposit of choice\n2. Check Balance\n3. SMS Statement\n4. Early Withdrawal\n5. Withdraw\n6. Auto Rollovers\n7. Change Pin\n8. Terms and Conditions\n0. End"
                send_response(conn, response)
            end
            if checkMenuLength>3 do
                valueEntered = Enum.at(checkMenu, 2)
                Logger.info (valueEntered);
                case valueEntered do
                    "1" ->
                        Logger.info ("handleMakeDepositChoice");
                        handleMakeDepositChoice(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
                    "2" ->
                        Logger.info ("handleGetSavingsBalance");
                        handleGetSavingsBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
                    "3" ->
                        Logger.info ("handleGetSMSStatement");
                        handleGetSMSStatement(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
                    "4" ->
                        Logger.info ("handleGetLoan");
                        handleDivest(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
                    "5" ->
                        Logger.info ("handleGetLoan");
                        handleWithdrawal(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
                    "6" ->
                        Logger.info ("Change pin")
                        handleAutoRollovers(conn, mobile_number, cmd, text, checkMenu, client, clientTelco)
                    "7" ->
                        Logger.info ("Change pin")
                        handleChangePin(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, "Enter your current pin")
                    "8" ->
                        Logger.info ("handleGetLoan");
                        handleTC(conn, mobile_number, cmd, text, checkMenu)
                    "0" ->
                        Logger.info ("handleGetLoan");
                        text = "Thank you and good bye";
						#response = %{
						#	Message: text,
						#	ClientState: 1,
						#	Type: "Response",
						#	key: "END"
						#}
						response = text
						send_response(conn, response)
					_ ->
                        Logger.info ("handleGetLoan");
                        text = "Invaid number entered\n\nPress \nb. Back \n0. End";
						#response = %{
						#	Message: text,
						#	ClientState: 1,
						#	Type: "Response",
						#	key: "END"
						#}
						response = text
						send_response(conn, response)


                end
            end

        else
            handle_new_account(conn, mobile_number, cmd, text, users, client, clientTelco)
        end

    end



	def displayAutoRollovers(conn, mobile_number, cmd, text, checkMenu) do
		query = from au in User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUsers = Repo.all(query);
		appUser = Enum.at(appUsers, 0);


		isMatured = false
		isDivested = false
		status = "ACTIVE"
		autoCreditOnMaturityDone = false;
		autoCreditOnMaturity = true;
		query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
			where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.autoCreditOnMaturity == type(^autoCreditOnMaturity, :boolean) 
				and au.autoCreditOnMaturityDone == type(^autoCreditOnMaturityDone, :boolean) and au.fixedDepositStatus == type(^status, :string) and au.userId >= type(^appUser.id, :integer)),
			select: au
		fixedDeposits = Repo.all(query);
		
			Logger.info "=========="
			Logger.info Enum.count(fixedDeposits)

		if Enum.count(fixedDeposits)>0 do

			#acc = Enum.reduce(fixedDeposits, fn x,
			#    acc -> x.id * acc
			#end)

			if Enum.count(fixedDeposits)>0 do

				#acc = Enum.reduce(fixedDeposits, fn x,
				#    acc -> x.id * acc
				#end)

				totals = for x <- 0..(Enum.count(fixedDeposits)-1) do
					fixedDeposit = Enum.at(fixedDeposits, x);

					fullValue = Decimal.round(Decimal.from_float(fixedDeposit.principalAmount + fixedDeposit.expectedInterest), fixedDeposit.currencyDecimals)
					fixedAmount = Decimal.round(Decimal.from_float(fixedDeposit.principalAmount), fixedDeposit.currencyDecimals)
					id = "#{fixedDeposit.id}";
					idLen = String.length(id);

					fixedDepositNumber = String.pad_leading("#{fixedDeposit.id}", (6 - idLen), "0");
					autoRollOverAmount = Decimal.round(Decimal.from_float(fixedDeposit.autoRollOverAmount), fixedDeposit.currencyDecimals)
					endDate = DateTime.to_date(fixedDeposit.endDate);
					totals = "#{(x+1)}. Ref ##{fixedDepositNumber}\nFixed Deposit: #{fixedDeposit.currency}#{fixedAmount}\nValue At Maturity: #{fixedDeposit.currency}#{fullValue}\nValue Date: #{endDate}\nRollover Amount: #{fixedDeposit.currency}#{autoRollOverAmount}\n\n";

				end


				Logger.info Enum.count(totals)
				Logger.info "==========>>>>>>>"
				acctStatement = (Enum.join(totals, "\n");)
				IO.inspect String.length(acctStatement);
				text = "Select a fixed deposit to remove its automatic rollover on maturity\n\n" <> acctStatement <> "\n\nb. Back \n0. End";

				response = text
				send_response(conn, response)
			else
				text = "You do not have any automatic rollovers on fixed deposits\n\nb. Back \n0. End";
				response = text;
				send_response(conn, response)
			end

			response = text
			send_response(conn, response)
		else
			text = "You do not have any automatic rollovers on fixed deposits\n\nb. Back \n0. End";
			response = text;
			send_response(conn, response)
		end
	end
	
	
	def createNewAutoRollover(conn, mobile_number, cmd, text, checkMenu) do
		query = from au in User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUsers = Repo.all(query);
		appUser = Enum.at(appUsers, 0);


		isMatured = false
		isDivested = false
		status = "ACTIVE"
		autoCreditOnMaturityDone = false;
		autoCreditOnMaturity = false;
		query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
			where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.autoCreditOnMaturity == type(^autoCreditOnMaturity, :boolean) 
				and au.autoCreditOnMaturityDone == type(^autoCreditOnMaturityDone, :boolean) and au.fixedDepositStatus == type(^status, :string) and au.userId >= type(^appUser.id, :integer)),
			select: au
		fixedDeposits = Repo.all(query);
		
			Logger.info "=========="
			Logger.info Enum.count(fixedDeposits)

		if Enum.count(fixedDeposits)>0 do

			#acc = Enum.reduce(fixedDeposits, fn x,
			#    acc -> x.id * acc
			#end)

			if Enum.count(fixedDeposits)>0 do

				#acc = Enum.reduce(fixedDeposits, fn x,
				#    acc -> x.id * acc
				#end)

				totals = for x <- 0..(Enum.count(fixedDeposits)-1) do
					fixedDeposit = Enum.at(fixedDeposits, x);
					IO.inspect fixedDeposit;

					fullValue = Decimal.round(Decimal.from_float(fixedDeposit.principalAmount + fixedDeposit.expectedInterest), fixedDeposit.currencyDecimals)
					fixedAmount = Decimal.round(Decimal.from_float(fixedDeposit.principalAmount), fixedDeposit.currencyDecimals)
					id = "#{fixedDeposit.id}";
					idLen = String.length(id);

					fixedDepositNumber = String.pad_leading("#{fixedDeposit.id}", (6 - idLen), "0");
					autoRollOverAmount = if(!is_nil(fixedDeposit.autoRollOverAmount)) do 
						autoRollOverAmount = Decimal.round(Decimal.from_float(fixedDeposit.autoRollOverAmount), fixedDeposit.currencyDecimals)
					else
						0.00
					end
					endDate = DateTime.to_date(fixedDeposit.endDate);
					totals = "#{(x+1)}. Ref ##{fixedDepositNumber}\nFixed Deposit: #{fixedDeposit.currency}#{fixedAmount }\nValue At Maturity: #{fixedDeposit.currency}#{fullValue}\nValue Date: #{endDate}\nRollover Amount: #{fixedDeposit.currency }#{autoRollOverAmount}\n\n";

				end


				Logger.info Enum.count(totals)
				Logger.info "==========>>>>>>>"
				acctStatement = (Enum.join(totals, "\n");)
				IO.inspect String.length(acctStatement);
				text = "Select a fixed deposit to add an automatic rollover on maturity\n\n" <> acctStatement <> "\n\nb. Back \n0. End";

				response = text
				send_response(conn, response)
			else
				text = "There are no fixed deposits to fix an automatic rollover on\n\nb. Back \n0. End";
				response = text;
				send_response(conn, response)
			end

			response = text
			send_response(conn, response)
		else
			text = "There are no fixed deposits to fix an automatic rollover on\n\nb. Back \n0. End";
			response = text;
			send_response(conn, response)
		end
	end
	
	def deleteAutoRollover(conn, mobile_number, cmd, text, checkMenu) do
		checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-2))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
		IO.inspect checkMenu;
		
		query = from au in User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUsers = Repo.all(query);
		appUser = Enum.at(appUsers, 0);


		isMatured = false
		isDivested = false
		status = "ACTIVE"
		autoCreditOnMaturityDone = false;
		autoCreditOnMaturity = true;
		query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
			where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.autoCreditOnMaturity == type(^autoCreditOnMaturity, :boolean) 
				and au.autoCreditOnMaturityDone == type(^autoCreditOnMaturityDone, :boolean) and au.fixedDepositStatus == type(^status, :string) and au.userId >= type(^appUser.id, :integer)),
			select: au
		fixedDeposits = Repo.all(query);
		
			Logger.info "=========="
			Logger.info Enum.count(fixedDeposits)

		if Enum.count(fixedDeposits)>0 do

			valueEntered = elem Integer.parse(valueEntered), 0
			fixedDeposit = Enum.at(fixedDeposits, (valueEntered-1));
			
			IO.inspect fixedDeposit
			attrs = %{autoCreditOnMaturityDone: false, autoCreditOnMaturity: false, autoRollOverAmount: 0.00}
			
			fixedDeposit
			|> LoanSavingsSystem.FixedDeposit.FixedDeposits.changesetForUpdate(attrs)
			|> Repo.update()

			idLen = String.length("#{fixedDeposit.id}");
			fixedDepositNumber = String.pad_leading("#{fixedDeposit.id}", (6 - idLen), "0");
			text = "Automatic rollover has been removed for your fixed deposit ##{fixedDepositNumber}\n\nb. Back \n0. End";

			response = text
			send_response(conn, response)
		else
			text = "You do not have any automatic rollovers on fixed deposits\n\nb. Back \n0. End";
			response = text;
			send_response(conn, response)
		end
	end
	
	
	
	
	def enterRolloverAmount(conn, mobile_number, cmd, text, checkMenu) do
		checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-2))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
		IO.inspect checkMenu;
		
		query = from au in User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUsers = Repo.all(query);
		appUser = Enum.at(appUsers, 0);


		isMatured = false
		isDivested = false
		status = "ACTIVE"
		autoCreditOnMaturityDone = false;
		autoCreditOnMaturity = false;
		query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
			where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.autoCreditOnMaturity == type(^autoCreditOnMaturity, :boolean) 
				and au.autoCreditOnMaturityDone == type(^autoCreditOnMaturityDone, :boolean) and au.fixedDepositStatus == type(^status, :string) and au.userId >= type(^appUser.id, :integer)),
			select: au
		fixedDeposits = Repo.all(query);
		
			Logger.info ">>=========="
			Logger.info Enum.count(fixedDeposits)

		if Enum.count(fixedDeposits)>0 do

			valueEntered = elem Integer.parse(valueEntered), 0
			fixedDeposit = Enum.at(fixedDeposits, (valueEntered - 1));
			
			IO.inspect fixedDeposit

			idLen = String.length("#{fixedDeposit.id}");
			fixedDepositNumber = String.pad_leading("#{fixedDeposit.id}", (6 - idLen), "0");
			currency = fixedDeposit.currency;
			maturityValue = fixedDeposit.principalAmount + fixedDeposit.expectedInterest
			maturityValue = Decimal.round(Decimal.from_float(maturityValue), fixedDeposit.currencyDecimals)
			text = "Add an automatic rollover for the fixed deposit  ##{fixedDepositNumber}. The balance will be transfered to your Airtel Mobile money account.\nHow much do you want to reinvest? Maximum allowed is #{currency}#{maturityValue} \n\nb. Back \n0. End";

			response = text
			send_response(conn, response)
		else
			text = "You do not have any fixed deposits to add an automatic rollover on\n\nb. Back \n0. End";
			response = text;
			send_response(conn, response)
		end
	end
	
	
	
	def applyRolloverAmount(conn, mobile_number, cmd, text, checkMenu) do
		checkMenuLength = Enum.count(checkMenu)
		fdSelected = Enum.at(checkMenu, (checkMenuLength-3))
        valueEntered = Enum.at(checkMenu, (checkMenuLength-2))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
		IO.inspect checkMenu;
		valueEntered = elem Float.parse(valueEntered), 0
		
		query = from au in User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUsers = Repo.all(query);
		appUser = Enum.at(appUsers, 0);


		isMatured = false
		isDivested = false
		status = "ACTIVE"
		autoCreditOnMaturityDone = false;
		autoCreditOnMaturity = false;
		query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
			where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.autoCreditOnMaturity == type(^autoCreditOnMaturity, :boolean) 
				and au.autoCreditOnMaturityDone == type(^autoCreditOnMaturityDone, :boolean) and au.fixedDepositStatus == type(^status, :string) and au.userId >= type(^appUser.id, :integer)),
			select: au
		fixedDeposits = Repo.all(query);
		
			Logger.info ">>=========="
			Logger.info Enum.count(fixedDeposits)

		if Enum.count(fixedDeposits)>0 do

			fdSelected = elem Integer.parse(fdSelected), 0
			fixedDeposit = Enum.at(fixedDeposits, (fdSelected - 1));
			
			IO.inspect fixedDeposit
			attrs = %{autoCreditOnMaturityDone: false, autoCreditOnMaturity: true, autoRollOverAmount: valueEntered}
			
			fixedDeposit
			|> LoanSavingsSystem.FixedDeposit.FixedDeposits.changesetForUpdate(attrs)
			|> Repo.update()

			idLen = String.length("#{fixedDeposit.id}");
			fixedDepositNumber = String.pad_leading("#{fixedDeposit.id}", (6 - idLen), "0");
			ntotals = calculate_maturity_repayments(valueEntered, fixedDeposit.fixedPeriod,
				fixedDeposit.interestRate, fixedDeposit.yearLengthInDays, fixedDeposit.productInterestMode,
				fixedDeposit.interestRateType, fixedDeposit.fixedPeriodType)
			ntotals = Decimal.round(Decimal.from_float(ntotals),fixedDeposit.currencyDecimals)
						   
						   
			text = "Automatic rollover has been added for your fixed deposit ##{fixedDepositNumber} for a period of #{fixedDeposit.fixedPeriod} #{fixedDeposit.fixedPeriodType} yielding you an interest of #{fixedDeposit.currency}#{ntotals}. This instruction will be effected at the point of maturity\n\nb. Back \n0. End";

			response = text
			send_response(conn, response)
		else
			text = "You do not have any fixed deposits to add an automatic rollover on\n\nb. Back \n0. End";
			response = text;
			send_response(conn, response)
		end
	end
	
	
	
	
	def createNewAutoRollover(conn, mobile_number, cmd, text, checkMenu) do
	
		checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-1))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
		IO.inspect checkMenu;
	end



	def handleAutoRollovers(conn, mobile_number, cmd, text, checkMenu, client, clientTelco) do
		checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-1))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
		IO.inspect checkMenu;
		
        if valueEntered == "b" do
            #response = %{
            #    Message: "BA3",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA3"
            #}
			response = "BA3"
            send_response(conn, response)
        else
            case checkMenuLength do
				4 ->
					text = "Press\n\n1. View Auto Rollovers\n2. Set an Automatic Rollover\nb. Back \n0. End";
					response = text
					send_response(conn, response)
				5 ->
					valueEntered = Enum.at(checkMenu, (3))
                    Logger.info (valueEntered);
                    case valueEntered do
                        "1" ->
                            Logger.info ("displayAutoRollovers");
                            displayAutoRollovers(conn, mobile_number, cmd, text, checkMenu)
						"2" ->
                            Logger.info ("createNew");
                            createNewAutoRollover(conn, mobile_number, cmd, text, checkMenu)

                    end
                6 ->
                    valueEntered = Enum.at(checkMenu, (3))
                    Logger.info (valueEntered);
                    case valueEntered do
                        "1" ->
                            Logger.info ("deleteAutoRollover");
                            deleteAutoRollover(conn, mobile_number, cmd, text, checkMenu)
						"2" ->
                            Logger.info ("enterRolloverAmount");
                            enterRolloverAmount(conn, mobile_number, cmd, text, checkMenu)

                    end
                7 ->
                    valueEntered = Enum.at(checkMenu, (3))
                    Logger.info (valueEntered);
                    case valueEntered do
                        "2" ->
                            Logger.info ("enterRolloverAmount");
                            applyRolloverAmount(conn, mobile_number, cmd, text, checkMenu)

                    end
            end
        end
	end



    def handleGetSMSStatement(conn, mobile_number, cmd, text, checkMenu, client, clientTelco) do
        checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-1))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        IO.inspect (checkMenu);
        Logger.info(valueEntered);
        Logger.info(text);
        if valueEntered == "b" do
            #response = %{
            #    Message: "BA3",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA3"
            #}

			response = "BA3";
            send_response(conn, response)
        else
            case checkMenuLength do
				4 ->
					response = "Choose your preferred option to receive your statement:\n\n1. View on ZIPAKE USSD\n2. Send to my email\n\nb. Back \n0. End"
					send_response(conn, response)
                5 ->
                    selectedIndex = Enum.at(checkMenu, 3)
					
					if(checkIfInteger(selectedIndex)===false) do
						response = "Invalid entry. Press\n\nb. Back\n0. Exit"
						send_response(conn, response)
					else
						selectedIndex = elem Integer.parse(selectedIndex), 0

						if(selectedIndex==1) do
							handleReceiveStatement(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, selectedIndex)
						else
							if(selectedIndex==2) do
								response = "Enter your email address:\n\nb. Back \n0. End"
								send_response(conn, response)
							else
								response = "Invalid entry\n\nPress\nb. Back \n0. End"
								send_response(conn, response)
							end
						end
					end

				6 ->
                    selectedIndex = Enum.at(checkMenu, 3)
					
					if(selectedIndex !== "1") do
						selectedIndex = elem Integer.parse(selectedIndex), 0
						emailAddress = Enum.at(checkMenu, 4)
						IO.inspect "emailAddress....#{emailAddress}";
						#emailAddress = "smicer66@gmail.com"

						case validate_email(emailAddress) do
							false ->
								IO.inspect "fail"
								response = "Invalid email address provided. Please go back to enter a valid email address\n\n1. View on ZIPAKE USSD\n2. Send to my email\n\nb. Back \n0. End"
								send_response(conn, response)
							true ->
								query = from au in User,
									where: (au.username == type(^mobile_number, :string)),
									select: au
								appUser = Repo.one(query);

								query = from au in LoanSavingsSystem.Client.UserBioData, where: au.userId == ^appUser.id, select: au
								userBioData = Repo.one(query)
								html = "<html>";
									html = html <> "<body>";
										html = html <> "<div style=\"width: 100% !important\">";
											html = html <> "<div style=\"width: 100% !important\">";
												html = html <> "<img src=\"http://localhost:5000/images/logo/Microfinance-logo2.jpg\" style=\"height: 100px\">";
											html = html <> "<div>";
											html = html <> "<div style=\"width: 100% !important\">";
												html = html <> "<h3>ZIPAKE - Customer Statement Of Account</h3>";
											html = html <> "<div>";
											html = html <> "<div style=\"width: 100% !important\">";
												html = html <> "<div style=\"width: 30%; float: left !important; \">";
													html = html <> "<strong>Account Name:</strong>";
												html = html <> "</div>";
												html = html <> "<div style=\"width: 70%; float: left !important; \">";
													html = html <> "<span>#{userBioData.firstName} #{userBioData.lastName}</span>";
												html = html <> "</div>";
												html = html <> "<div style=\"width: 30%; float: left !important; \">";
													html = html <> "<strong>Mobile Number:</strong>";
												html = html <> "</div>";
												html = html <> "<div style=\"width: 70%; float: left !important; \">";
													html = html <> "<span>#{appUser.username}</span>";
												html = html <> "</div>";
												html = html <> "<div style=\"width: 30%; float: left !important; \">";
													html = html <> "<strong>Statement Date:</strong>";
												html = html <> "</div>";
												html = html <> "<div style=\"width: 70%; float: left !important; \">";
													html = html <> "<span>#{Date.utc_today}</span>";
												html = html <> "</div>";
											html = html <> "<div>";
										html = html <> "</div>";


										html = html <> "<div style=\"width: 100% !important\">";


											html = html <> "<table style=\"width: 100% !important\">";
												html = html <> "<thead>";
													html = html <> "<tr>";
														html = html <> "<th style=\"text-align: left !important; padding: 15px !important; background-color: #011949 !important; color: #fff !important\">Date</th>";
														html = html <> "<th style=\"text-align: left !important; padding: 15px !important; background-color: #011949 !important; color: #fff !important\">Transaction Description</th>";
														html = html <> "<th style=\"text-align: right !important; padding: 15px !important; background-color: #011949 !important; color: #fff !important\">Debit</th>";
														html = html <> "<th style=\"text-align: right !important; padding: 15px !important; background-color: #011949 !important; color: #fff !important\">Credit</th>";
														html = html <> "<th style=\"text-align: right !important; padding: 15px !important; background-color: #011949 !important; color: #fff !important\">Balance</th>";
													html = html <> "</tr>";
												html = html <> "</thead>";
												html = html <> "<tbody>";


												query = from au in Transaction,
													where: (au.userId == type(^appUser.id, :integer)),
													select: au
												transactions = Repo.all(query);
												tableEntries = [];
												tableEntries = for x <- 0..(Enum.count(transactions)-1) do
													transaction = Enum.at(transactions, x);
													tAmount = Float.ceil(transaction.totalAmount, client.defaultCurrencyDecimals)
													tAmount = :erlang.float_to_binary((tAmount), [{:decimals, client.defaultCurrencyDecimals}])
													tdt = transaction.inserted_at
													tdt = NaiveDateTime.to_string(tdt);
													IO.inspect tdt
													tdt = String.slice(tdt, 0, 10);
													IO.inspect tdt;
													tableEntry = "<tr>";
														tableEntry = tableEntry <> "<td style=\"text-align: left !important\">#{tdt}</td>";
														tableEntry = tableEntry <> "<td style=\"text-align: left !important\">#{transaction.transactionDetail}</td>";
														tableEntry = if (transaction.transactionType=="CR") do
															tableEntry = tableEntry <> "<td style=\"text-align: right !important\">&nbsp;</td>";
															tableEntry = tableEntry <> "<td style=\"text-align: right !important\">#{tAmount}</td>";
															tableEntry
														else
															tableEntry = tableEntry <> "<td style=\"text-align: right !important\">#{tAmount}</td>";
															tableEntry = tableEntry <> "<td style=\"text-align: right !important\">&nbsp;</td>";
															tableEntry
														end
														tableEntry = tableEntry <> "<td style=\"text-align: right !important\">#{:erlang.float_to_binary((Float.ceil(transaction.newTotalBalance, client.defaultCurrencyDecimals)), [{:decimals, client.defaultCurrencyDecimals}])}</td>";
													tableEntry = tableEntry <> "</tr>";
													tableEntries = tableEntries ++ [tableEntry];
													tableEntries
												end

												tableEntries = Enum.join(tableEntries, "\n");
												html = html <> tableEntries;
												html = html <> "</tbody>";
											html = html <> "<table>";



										html = html <> "</div>";
									html = html <> "</body>";
								html = html <> "</html>";
								showfilename = "Statement of Account for #{userBioData.firstName}  #{userBioData.lastName}"
								{:ok, filename}    = PdfGenerator.generate(html, page_size: "A5", filename: showfilename)
								IO.inspect "filename"
								IO.inspect filename
								Email.send_statement_of_account(emailAddress, userBioData, client, filename)
								#handleReceiveStatement(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, selectedIndex)
								response = "Your statement of account has been sent to your email address - #{emailAddress}\n\nPress \nb. Back \n0. End"
								send_response(conn, response);
						end
					else
					
						response = "Invalid entry\n\nPress \nb. Back \n0. End"
						send_response(conn, response);
					end
				_ ->
					response = "Invalid entry.\n\nPress \nb. Back \n0. End"
					send_response(conn, response);
            end
        end

    end


	

	def validate_email(email) do
		r = EmailChecker.valid?(email)
		IO.inspect r
		IO.inspect email
		r
    end


	def handleReceiveStatement(conn, mobile_number, cmd, text, checkMenu, client, clientTelco, selectedIndex) do
		query = from au in User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUsers = Repo.all(query);
		appUser = Enum.at(appUsers, 0);



		individualRoleType = "INDIVIDUAL"
		query = from au in LoanSavingsSystem.Accounts.UserRole,
			where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
			select: au
		userRoles = Repo.all(query);
		userRole = Enum.at(userRoles, 0);


		status = "Disbursed";
		isMatured = false
		isDivested = false
		query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
			where: (au.userId >= type(^appUser.id, :integer)),				#au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and 
			select: au
		fixedDeposits = Repo.all(query);
		totalBalance = 0.00;

			Logger.info "=========="
			Logger.info Enum.count(fixedDeposits)

		if Enum.count(fixedDeposits)>0 do

			#acc = Enum.reduce(fixedDeposits, fn x,
			#    acc -> x.id * acc
			#end)

			totals = for x <- 0..(Enum.count(fixedDeposits)-1) do
				#totalBalance = Enum.each(fixedDeposits, fn(fixedDeposit) ->
				fixedDeposit = Enum.at(fixedDeposits, x);


				query = from au in LoanSavingsSystem.Products.Product,
					where: (au.id == ^fixedDeposit.productId),
					select: au
				products = Repo.all(query);
				product = Enum.at(products, 0);

				period = 0;
				days = Date.diff(Date.utc_today, fixedDeposit.startDate)
				daysValue = Date.diff(fixedDeposit.endDate, fixedDeposit.startDate)


				#ntotals = calculate_maturity_repayments(fixedDeposit.principalAmount, days,
				#   fixedDeposit.interestRate, fixedDeposit.yearLengthInDays, product.interestMode,
				#   product.interestType, fixedDeposit.fixedPeriodType)
				
				ntotals = fixedDeposit.principalAmount + fixedDeposit.accruedInterest;

				ntotalsAtDueDate = fixedDeposit.principalAmount + fixedDeposit.expectedInterest
				fullValue = Float.ceil(ntotalsAtDueDate, fixedDeposit.currencyDecimals)

				Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
				Logger.info ntotals
				endDate = case fixedDeposit.fixedPeriodType do
					"Days" ->
						endDate = Date.add(Date.utc_today, fixedDeposit.fixedPeriod)
						endDate
					"Months" ->
						endDate = Date.add(Date.utc_today, fixedDeposit.fixedPeriod*30)
						endDate
					"Years" ->
						endDate = Date.add(Date.utc_today, fixedDeposit.fixedPeriod*fixedDeposit.yearLengthInDays)
						endDate
				end
				#currentValue = Float.ceil(ntotals, fixedDeposit.currencyDecimals)

				currentValue = ntotals;
				currentValue = :erlang.float_to_binary((currentValue), [{:decimals, fixedDeposit.currencyDecimals}])

				#fixedAmount = Float.ceil(fixedDeposit.principalAmount, fixedDeposit.currencyDecimals)
				fixedAmount = Float.ceil(fixedDeposit.principalAmount, fixedDeposit.currencyDecimals)
				fixedAmount = :erlang.float_to_binary((fixedDeposit.principalAmount), [{:decimals, fixedDeposit.currencyDecimals}])
				
				currentStatus = 
				if(fixedDeposit.fixedDepositStatus=="ACTIVE") do
					currentStatus = 
					if(!is_nil(fixedDeposit.isMatured) && fixedDeposit.isMatured==true) do
						currentStatus = 
						if(!is_nil(fixedDeposit.isWithdrawn) && fixedDeposit.isWithdrawn==true) do
							currentStatus = "Matured & Withdrawn";
							currentStatus
						else
							currentStatus = "Matured";
							currentStatus
						end
					else
						currentStatus = 
						if(!is_nil(fixedDeposit.isDivested) && fixedDeposit.isDivested==true) do
							currentStatus = "Divested";
							currentStatus
						else
							currentStatus = "Active";
							currentStatus
						end
					end
					
				else
					currentStatus = String.capitalize(fixedDeposit.fixedDepositStatus);
					currentStatus
				end
				
				
				"Fixed Deposit: " <> fixedDeposit.currency <> "#{fixedAmount}\nCurrent Value: " <> fixedDeposit.currency <> "#{currentValue}\nDeposit Date: #{fixedDeposit.startDate}\nValue At Maturity: " <> fixedDeposit.currency <> "#{fullValue}\nValue Date: #{endDate}\nStatus: #{currentStatus}\n"
			end


			Logger.info Enum.count(totals)
			Logger.info "=========="
			acctStatement = (Enum.join(totals, "\n");)
			text = "Total Balance as at today:\n\n" <> acctStatement <> "\n\nPress \nb. Back \n0. End";
			#response = %{
			#    Message: text,
			#    ClientState: 1,
			#    Type: "Response",
			#    key: "CON"
			#}
			response = text
			send_response(conn, response)
		else
			text = "You do not have any fixed deposits at the moment\n\nPress \nb. Back \n0. End";
			#response = %{
			#    Message: text,
			#    ClientState: 1,
			#    Type: "Response",
			#    key: "CON"
			#}
			response = text
			send_response(conn, response)
		end
	end


    def handle_new_account(conn, mobile_number, cmd, text, users, client, clientTelco) do
        Logger.info("===================")
        Logger.info(cmd)
        Logger.info(mobile_number)


        Logger.info("short_code...")
        Logger.info(cmd)
        Logger.info("text...")
        Logger.info(text)
        clientId = client.id
        appUser = Enum.at(users, 0)
        userId = appUser.id
        clientName = client.clientName


        if text do
            checkMenu = String.split(text, "\*")
            checkMenuLength = Enum.count(checkMenu)
            Logger.info(checkMenuLength)


            status = "Active"
            roleType = "INDIVIDUAL"
            otp = Enum.random(1_000..9_999)
            otp = Integer.to_string(otp)
            appUserRole = %LoanSavingsSystem.Accounts.UserRole{roleType: roleType, status: status, userId: userId, clientId: clientId, otp: otp}
            case Repo.insert(appUserRole) do
                {:ok, appUserRole} ->
                    accountNo = mobile_number
                    accountType = "SAVINGS"
                    accountVersion = clientTelco.accountVersion
                    clientId = client.id
                    currencyDecimals = client.defaultCurrencyDecimals
                    currencyId = client.defaultCurrencyId
                    currencyName = client.defaultCurrencyName
                    status = "Active"
                    totalCharges = 0.00;
                    totalDeposits = 0.00;
                    totalInterestEarned = 0.00;
                    totalInterestPosted = 0.00;
                    totalPenalties = 0.00;
                    totalTax = 0.00;
                    totalWithdrawals = 0.00;
                    userId = appUser.id;
                    userRoleId = appUserRole.id;


                    account = %LoanSavingsSystem.Accounts.Account{
                        accountNo: accountNo,
                        accountType: accountType,
                        accountVersion: accountVersion,
                        clientId: clientId,
                        currencyDecimals: currencyDecimals,
                        currencyId: currencyId,
                        currencyName: currencyName,
                        status: status,
                        totalCharges: totalCharges,
                        totalDeposits: totalDeposits,
                        totalInterestEarned: totalInterestEarned,
                        totalInterestPosted: totalInterestPosted,
                        totalPenalties: totalPenalties,
                        totalTax: totalTax,
                        totalWithdrawals: totalWithdrawals,
                        userId: userId,
                        userRoleId: userRoleId,
                    }
                    case Repo.insert(account) do
                      {:ok, account} ->
                            #response = %{
                            #    Message: "Your new #{clientName} account has been setup for you. Press\n\nb. Back\n0. Log Out",
                            #    ClientState: 1,
                            #    Type: "Response",
                            #    key: "BA3"
                            #}
							response = "Your new #{clientName} account has been setup for you. Press\n\nb. Back\n0. Log Out"
                            send_response(conn, response)


                      {:error, changeset} ->
                            Logger.info("Fail")
                            #response = %{
                            #    Message: "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out",
                            #    ClientState: 1,
                            #    Type: "Response",
                            #    key: "BA3"
                            #}

							response = "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out"
                            send_response(conn, response)
                    end
                {:error, changeset} ->
                    Logger.info("Fail")
                    #response = %{
                    #    Message: "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out",
                    #    ClientState: 1,
                    #    Type: "Response",
                    #   key: "BA3"
                    #}

					response = "Your new #{clientName} account could not be setup for you. Press\n\nb. Back\n0. Log Out"
                    send_response(conn, response)
            end
        else
            #response = %{
            #    Message: "Invalid input provided",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA1"
            #}

			response = "Invalid input provided"
            send_response(conn, response)
        end

    end


    def handleTC(conn, mobile_number, cmd, text, checkMenu) do
        checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-1))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
        if valueEntered == "b" do
            tempText = text <> "*";
            tempCheckMenu = String.split(tempText, "*b*")
            tempCheckMenuFirst = Enum.at(tempCheckMenu, 0);
            tempCheckMenuLength = Enum.count(tempCheckMenu);
            tempCheckMenuLast = Enum.at(tempCheckMenu, tempCheckMenuLength-1);

            nText = tempCheckMenuLast
            #response = %{
            #    Message: nText,
            #    ClientState: 1,
            #    Type: "Response"
            #}
			response = nText
            send_response(conn, response)
        else
            tc = "Terms & Conditions\n-------------------------\nTo read our Terms and Conditions, click on the link - https://probasepay.com/zipake_terms_conditions.pdf \n\nb= Back\n0= End";
            #response = %{
            #    Message: tc,
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "END"
            #}
			response = tc
            send_response(conn, response);
        end
    end


    def handleGetSavingsBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco) do
        checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-1))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
        if valueEntered == "b" do
            #response = %{
            #    Message: "BA3",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA3"
            #}
			response = "BA3"
            send_response(conn, response)
        else
            case checkMenuLength do
                4 ->
                    query = from au in User,
                        where: (au.username == type(^mobile_number, :string)),
                        select: au
                    appUsers = Repo.all(query);
                    appUser = Enum.at(appUsers, 0);



                    individualRoleType = "INDIVIDUAL"
                    query = from au in LoanSavingsSystem.Accounts.UserRole,
                        where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
                        select: au
                    userRoles = Repo.all(query);
                    userRole = Enum.at(userRoles, 0);


                    status = "Disbursed";
                    isMatured = false
                    isDivested = false
                    query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
                        where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.userId >= type(^appUser.id, :integer)),
                        select: au
                    fixedDeposits = Repo.all(query);
                    totalBalance = 0.00;

                        Logger.info "=========="
                        Logger.info Enum.count(fixedDeposits)

                    if Enum.count(fixedDeposits)>0 do

                        #acc = Enum.reduce(fixedDeposits, fn x,
                        #    acc -> x.id * acc
                        #end)

                        totals = for x <- 0..(Enum.count(fixedDeposits)-1) do
                            #totalBalance = Enum.each(fixedDeposits, fn(fixedDeposit) ->
                            fixedDeposit = Enum.at(fixedDeposits, x);


                            query = from au in LoanSavingsSystem.Products.Product,
                                where: (au.id == ^fixedDeposit.productId),
                                select: au
                            products = Repo.all(query);
                            product = Enum.at(products, 0);

                            period = 0;
                            days = Date.diff(Date.utc_today, fixedDeposit.startDate)


                            #ntotals = calculate_maturity_repayments(fixedDeposit.principalAmount, days,
                            #   fixedDeposit.interestRate, fixedDeposit.yearLengthInDays, product.interestMode,
                            #   product.interestType, fixedDeposit.fixedPeriodType)
							ntotals = fixedDeposit.principalAmount + fixedDeposit.accruedInterest;
                            Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
                            Logger.info ntotals
                            ntotals
                        end


                        Logger.info Enum.count(totals)
                        Logger.info "=========="
                        #totalBalance = Float.ceil(Enum.sum(totals), client.defaultCurrencyDecimals)
						#totalBalance = :erlang.float_to_binary(totalBalance, [{:decimals, 2}])
						totalBalance = Decimal.round(Decimal.from_float(Enum.sum(totals)), client.defaultCurrencyDecimals)
                        text = "Total Balance as at today is #{client.defaultCurrencyName}#{totalBalance}\n\nb. Back \n0. End";
                        #response = %{
                        #    Message: text,
                        #    ClientState: 1,
                        #    Type: "Response",
                        #    key: "CON"
                        #}

						response = text
                        send_response(conn, response)
					else
						text = "Total Balance as at today is #{client.defaultCurrencyName}0.00\n\nb. Back \n0. End";
						response = text
                        send_response(conn, response)
                    end
				_->
					text = "Invalid entry\n\nb. Back \n0. End";
					response = text
					send_response(conn, response)
            end
        end

    end
	
	
	
	def loginOrRecover(conn, mobile_number, cmd, text, ussdRequests, passwordRequestMessage, client, clientTelco) do
		Logger.info text
		orginal_short_code = cmd


		activeStatus = "ACTIVE";
		query = from au in LoanSavingsSystem.Accounts.User, where: au.username == ^mobile_number and au.status == ^activeStatus, select: au
		companyStaff = Repo.one(query)

		if(!is_nil(companyStaff)) do
			checkMenu = String.split(text, "\*")
			checkMenuLength = Enum.count(checkMenu)

			Logger.info("loginOrRecover [[[[[[]]]]]]")
			Logger.info(checkMenuLength)

			if checkMenuLength==3 do
				#response = %{
				#	Message: passwordRequestMessage,
				#	ClientState: 1,
				#	Type: "Response",
				#	key: "CON"
				#}
				response = passwordRequestMessage

				send_response(conn, response)
			else
				#if checkMenuLength==4 do
					#valueEntered = Enum.at(checkMenu, (Enum.count(checkMenu)-2))
					valueEntered = Enum.at(checkMenu, 2)
					IO.inspect ("valueEntered");
					IO.inspect  (valueEntered);
					valueEntered = elem Integer.parse(valueEntered), 0
					
					if (valueEntered==1) do
						request_user_password(conn, mobile_number, cmd, text, ussdRequests, "Welcome to MFZ Zipake Savings\n\nPlease enter your 4 digit Pin", client, clientTelco);
					else 
						if (valueEntered==2) do
							if checkMenuLength==4 do
								handleRecoverPin(conn, mobile_number, cmd, text, ussdRequests, passwordRequestMessage, client, clientTelco);
							else
								handleReadSecurityQuestionResponse(conn, mobile_number, cmd, text, ussdRequests, passwordRequestMessage, client, clientTelco, checkMenu, companyStaff);
							end
						else
							checkMenuSize = Enum.count(checkMenu) - 2;
							checkMenuUpd = Enum.slice(checkMenu, 0..checkMenuSize)
							IO.inspect checkMenuUpd
							IO.inspect checkMenuSize

							text = Enum.join(checkMenuUpd, "*");
							IO.inspect text
							text = text <> "*";
							IO.inspect text
							attrs = %{request_data: text}
							IO.inspect attrs

							ussdRequest = Enum.at(ussdRequests, 0);

							query = from au in UssdRequest, where: au.id == ^ussdRequest.id, select: au
								ussdRequest = Repo.one(query);
							IO.inspect ussdRequest
							ussdRequest
							|> UssdRequest.changesetForUpdate(attrs)
							|> Repo.update()

							#response = %{
							#    Message: "Invalid first name provided. Enter your first name",
							#    ClientState: 1,
							#    Type: "Response",
							#    key: "CON"
							#}

							response = "Invalid response provided.\n\nPress\n1. Login\n2. I Forgot My Pin\nb. Back \n0. End"
							send_response(conn, response)
						end
					end
				#else
				#	welcome_menu(conn, mobile_number, cmd, text, client, clientTelco)
				#end
			end

		else
			#handle_new_account(conn, mobile_number, cmd, text)
			#response = %{
			#	Message: "Invalid profile. An active profile mapped to this number could not be found. \nContact MFZ staff to assist you with reactivating your profile",
			#	ClientState: 1,
			#	Type: "Response",
			#	key: "END"
			#}

			response = "Invalid profile. An active profile mapped to this number could not be found. \nContact MFZ staff to assist you with reactivating your profile";

			send_response(conn, response)
		end
	end
	
	
	
	def handleRecoverPin(conn, mobile_number, cmd, text, ussdRequests, passwordRequestMessage, client, clientTelco) do
		Logger.info text
		orginal_short_code = cmd


		activeStatus = "ACTIVE";
		query = from au in LoanSavingsSystem.Accounts.User, where: au.username == ^mobile_number and au.status == ^activeStatus, select: au
		companyStaff = Repo.one(query)

		if(!is_nil(companyStaff)) do
		
			
			query = from au in LoanSavingsSystem.Accounts.SecurityQuestions, where: au.id == ^companyStaff.securityQuestionId, select: au
			securityQuestion = Repo.one(query)
			
			response = "Provide the answer to your security question:\n#{securityQuestion.question}";

			send_response(conn, response)

		else
			#handle_new_account(conn, mobile_number, cmd, text)
			#response = %{
			#	Message: "Invalid profile. An active profile mapped to this number could not be found. \nContact MFZ staff to assist you with reactivating your profile",
			#	ClientState: 1,
			#	Type: "Response",
			#	key: "END"
			#}

			response = "You can not recover your password as your profile is not currently active.\nContact MFZ staff to assist you with reactivating your profile";

			send_response(conn, response)
		end
	end
	
	
	
	def handleReadSecurityQuestionResponse(conn, mobile_number, cmd, text, ussdRequests, passwordRequestMessage, client, clientTelco, checkMenu, user) do
		IO.inspect checkMenu;
		checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-2))
        securityQuestionId = Enum.at(checkMenu, (checkMenuLength-3))
        Logger.info("handleReadSecurityQuestionResponse");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
		
		query = from au in LoanSavingsSystem.Client.UserBioData, where: au.userId == ^user.id, select: au
			userBioData = Repo.one(query);
		
		pin = Enum.random(1_000..9_999)
		pin = "#{pin}"
		IO.inspect "========>>>>>>"
		IO.inspect "New Pin"
		IO.inspect pin
		pinEnc = LoanSavingsSystem.Accounts.User.encrypt_password(pin)
		pinEnc = String.trim_trailing(pinEnc, " ")
													
		if(user.securityQuestionAnswer==String.downcase(valueEntered)) do
			IO.inspect "Update Pin";
			
			attrs = %{pin: pinEnc, security_question_fail_count: 0}

			user
			|> User.changeset(attrs)
			|> Repo.update()
							
			mobile_number = "260967307151"
			naive_datetime = Timex.now
			firstName = userBioData.firstName;
			
			sms = %{
				mobile: mobile_number,
				msg: "Dear #{firstName}, Your new ZIPAKE account pin is #{pin}. Please log in and change your pin for the security of your ZIPAKE account",
				status: "READY",
				type: "SMS",
				msg_count: "1",
				date_sent: naive_datetime
			}
			Sms.changeset(%Sms{}, sms)
			|> Repo.insert()
			
			text = "A new ZIPAKE account pin has been generated for you and sent in an SMS message to your mobile number. Press \n\nb. Login \n0. End";
			response = text
			send_response(conn, response)
		else
			IO.inspect "Invalid match";
			attrs = if(!is_nil(user.security_question_fail_count) && user.security_question_fail_count==2) do
				attrs = %{security_question_fail_count: (user.security_question_fail_count + 1), status: "BLOCKED"}
				attrs
			else
				attrs = if(is_nil(user.security_question_fail_count)) do
					attrs = %{security_question_fail_count: 1}
					attrs
				else
					attrs = %{security_question_fail_count: (user.security_question_fail_count + 1)}
					attrs
				end
			end

			user
			|> User.changeset(attrs)
			|> Repo.update()
								
			text = "Invalid answer provided to your security question. Press \n\nb. Back \n0. End";
			response = text
			send_response(conn, response)
		end
	end


    def handleRepayLoanBalance(conn, mobile_number, cmd, text, checkMenu) do
        checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-1))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
        if valueEntered == "b" do
            #response = %{
            #    Message: "BA3",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA3"
            #}
			response = "BA3"
            send_response(conn, response)
        else
            case checkMenuLength do
                3 ->
                    query = from au in User,
                        where: (au.mobile_number == type(^mobile_number, :string)),
                        select: au
                    appUsers = Repo.all(query);
                    appUser = Enum.at(appUsers, 0);


                    query = from au in Staff,
                        where: (au.id == type(^appUser.staff_id, :integer)),
                        select: au
                    staffs = Repo.all(query);
                    staff = Enum.at(staffs, 0);


                    status = "Disbursed";
                    query = from au in Loans,
                        where: (au.loan_status == type(^status, :string) and au.customer_id == type(^staff.id, :integer)),
                        select: au
                    loans = Repo.all(query);

                    if Enum.count(loans) > 0 do
                        loan = Enum.at(loans, 0);

                        outstandingTotal = loan.principal_outstanding_derived + loan.interest_outstanding_derived + loan.fee_charges_outstanding_derived + loan.penalty_charges_outstanding_derived;
                        Logger.info(outstandingTotal);
                        outstandingTotal = :erlang.float_to_binary(outstandingTotal, [decimals= 2])
                        principal_outstanding_derived = :erlang.float_to_binary(loan.principal_outstanding_derived, [decimals= 2])
                        interest_outstanding_derived = :erlang.float_to_binary(loan.interest_outstanding_derived, [decimals= 2])
                        fee_charges_outstanding_derived = :erlang.float_to_binary(loan.fee_charges_outstanding_derived, [decimals= 2])
                        penalty_charges_outstanding_derived = :erlang.float_to_binary(loan.penalty_charges_outstanding_derived, [decimals= 2])



                        text = "Loan Account ##{loan.loan_identity_number}\n\nOutstanding Balance= #{loan.currency_code}#{outstandingTotal}\n\n1. Pay Balance\nb. Back \n0. End";
                        #response = %{
                        #    Message: text,
                        #    ClientState: 1,
                        #    Type: "Response",
                        #    key: "CON"
                        #}
						response = text
                        send_response(conn, response)
                    else
                        text = "You do not have any loans at the moment. Apply for a loan first. Thank you\n\nb. Back \n0. End";
                        #response = %{
                        #    Message: text,
                        #    ClientState: 1,
                        #    Type: "Response",
                        #    key: "CON"
                        #}

						response = text
                        send_response(conn, response)
                    end
                4 ->
                    valueEntered = Enum.at(checkMenu, (3))
                    Logger.info (valueEntered);
                    case valueEntered do
                        "1" ->
                            Logger.info ("handleGetLoan");
                            payLoanBalance(conn, mobile_number, cmd, text, checkMenu)


                    end
            end
        end

    end



    def handleAccountStatus(conn, mobile_number, cmd, text, checkMenu) do
        checkMenuLength = Enum.count(checkMenu)
        valueEntered = Enum.at(checkMenu, (checkMenuLength-1))
        Logger.info("handleGetLoan");
        Logger.info(checkMenuLength);
        Logger.info(valueEntered);
        Logger.info(text);
        if valueEntered == "b" do
            #response = %{
            #    Message: "BA3",
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "BA3"
            #}
			response = "BA3"
            send_response(conn, response)
        else
            case checkMenuLength do
                3 ->
                    query = from au in User,
                        where: (au.mobile_number == type(^mobile_number, :string)),
                        select: au
                    appUsers = Repo.all(query);
                    appUser = Enum.at(appUsers, 0);


                    query = from au in Staff,
                        where: (au.id == type(^appUser.staff_id, :integer)),
                        select: au
                    staffs = Repo.all(query);
                    staff = Enum.at(staffs, 0);


                    if appUser.status == "Active" do

                        text = "Your account is active\n\n1. Pay Balance\nb. Back \n0. End";
                        #response = %{
                        #    Message: text,
                        #    ClientState: 1,
                        #    Type: "Response",
                        #    key: "CON"
                        #}
						response = text;
                        send_response(conn, response)
                    else
                         if appUser.status == "Inactive" do

                            text = "Your account is not active\n\n1. Pay Balance\nb. Back \n0. End";
                            #response = %{
                            #    Message: text,
                            #    ClientState: 1,
                            #    Type: "Response",
                            #    key: "CON"
                            #}

							response = text
                            send_response(conn, response)
                        else
                            text = "Your account has been blocked\n\n1. Pay Balance\nb. Back \n0. End";
                            #response = %{
                            #    Message: text,
                            #    ClientState: 1,
                            #    Type: "Response",
                            #    key: "CON"
                            #}
							response = text
                            send_response(conn, response)
                        end
                    end
            end
        end

    end


    def payLoanBalance(conn, mobile_number, cmd, text, checkMenu) do
        query = from au in User,
            where: (au.mobile_number == type(^mobile_number, :string)),
            select: au
        appUsers = Repo.all(query);
        appUser = Enum.at(appUsers, 0);


        query = from au in Staff,
            where: (au.id == type(^appUser.staff_id, :integer)),
            select: au
        staffs = Repo.all(query);
        staff = Enum.at(staffs, 0);


        status = "Disbursed";
        query = from au in Loans,
            where: (au.loan_status == type(^status, :string) and au.customer_id == type(^staff.id, :integer)),
            select: au
        loans = Repo.all(query);
        if Enum.count(loans)>0 do
            loan = Enum.at(loans, 0);

            outstandingTotal = loan.principal_outstanding_derived + loan.interest_outstanding_derived + loan.fee_charges_outstanding_derived + loan.penalty_charges_outstanding_derived;

            principal_outstanding_derived = :erlang.float_to_binary(loan.principal_outstanding_derived, [decimals= 2])
            interest_outstanding_derived = :erlang.float_to_binary(loan.interest_outstanding_derived, [decimals= 2])
            fee_charges_outstanding_derived = :erlang.float_to_binary(loan.fee_charges_outstanding_derived, [decimals= 2])
            penalty_charges_outstanding_derived = :erlang.float_to_binary(loan.penalty_charges_outstanding_derived, [decimals= 2])

            loan_id = loan.id
            is_reversed = false;
            transaction_type_enum = "LOAN REPAYMENT";
            transaction_date = Date.utc_today;
            principal_portion_derived = loan.principal_outstanding_derived;
            interest_portion_derived = loan.interest_outstanding_derived;
            fee_charges_portion_derived = loan.fee_charges_outstanding_derived;
            penalty_charges_portion_derived = loan.penalty_charges_outstanding_derived;
            overpayment_portion_derived = 0.00;
            unrecognized_income_portion = 0.00;
            outstanding_loan_balance_derived = 0.00;
            submitted_on_date = Date.utc_today;
            manually_adjusted_or_reversed = false;
            manually_created_by_userid = nil;
            amount = outstandingTotal;



            Logger.info "Insert Loan Repayment Transaction";
            # loanTransaction = %Transaction{loan_id= loan_id, is_reversed= is_reversed, transaction_type_enum= transaction_type_enum,
            #     transaction_date= transaction_date, amount= amount, principal_portion_derived= principal_portion_derived, interest_portion_derived= interest_portion_derived,
            #     fee_charges_portion_derived= fee_charges_portion_derived,
            #     penalty_charges_portion_derived= penalty_charges_portion_derived, overpayment_portion_derived= overpayment_portion_derived, unrecognized_income_portion= unrecognized_income_portion,
            #     outstanding_loan_balance_derived= outstanding_loan_balance_derived,
            #     submitted_on_date= submitted_on_date, manually_adjusted_or_reversed= manually_adjusted_or_reversed, manually_created_by_userid= manually_created_by_userid}
            # Repo.insert(loanTransaction);


            query = from au in LoanRepaymentSchedule,
                where: (au.loan_id == type(^loan_id, :integer)),
                select: au
            loanRepaymentSchedules = Repo.all(query)
            for {k, v} <- Enum.with_index(loanRepaymentSchedules) do
                loanRepaymentSchedule = Enum.at(loanRepaymentSchedules, v);
                obligations_met_on_date = Date.utc_today;
                completed_derived = loanRepaymentSchedule.principal_amount
                LoanRepaymentSchedule.changeset(loanRepaymentSchedule, %{obligations_met_on_date: obligations_met_on_date, completed_derived: completed_derived})
                    |> prepare_update(conn, loanRepaymentSchedule)
                    |> Repo.transaction()

            end

            closedon_date = Date.utc_today;
            completed_derived = loan.total_outstanding_derived;
            principal_repaid_derived = loan.approved_principal;
            interest_repaid_derived = loan.interest_charged_derived;
            fee_charges_repaid_derived = loan.fee_charges_charged_derived;
            Loans.changeset(loan, %{closedon_date: closedon_date, completed_derived: completed_derived,
                principal_repaid_derived: principal_repaid_derived, interest_repaid_derived: interest_repaid_derived, fee_charges_repaid_derived: fee_charges_repaid_derived
                })
                |> prepare_update(conn, loan)
                |> Repo.transaction()




            text = "Loan ##{loan.loan_identity_number} completely paid. Thank you\n\nb. Back \n0. End";
            #response = %{
            #    Message: text,
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "END"
            #}
			response = text
            send_response(conn, response)
        else
            text = "You do not have any loans. Apply for a loan first Thank you\n\nb. Back \n0. End";
            #response = %{
            #    Message: text,
            #    ClientState: 1,
            #    Type: "Response",
            #    key: "END"
            #}
			response = text
            send_response(conn, response);
        end
    end

    def prepare_update(changeset, conn, object) do
        Ecto.Multi.new()
        |> Ecto.Multi.update(:object, changeset)
    end




    def send_response(conn, response) do
        Logger.info  "Test!"
        Logger.info  Jason.encode!(response)
        #Logger.info response[:Message];
        #send_resp(conn, :ok, Jason.encode!(response))

        #put_resp_header(conn, "Content-type", "text/html; charset=utf-8");
        #put_resp_header(conn, "Freeflow", "FC");
        #send_resp(conn, :ok, response)


        conn
        |> put_status(:ok)
        |> put_resp_header("Freeflow", "FC")
        |> send_resp(:ok, response)


    end



    def send_response_with_header(conn, response) do
        Logger.info  "Test!"
        Logger.info  Jason.encode!(response)
        #Logger.info response[:Message];
        #send_resp(conn, :ok, Jason.encode!(response))
        #put_resp_header(conn, "Content-type", "text/html; charset=utf-8");
        #put_resp_header(conn, "Freeflow", "FB");
        #send_resp(conn, :ok, response)
        conn
        |> put_status(:ok)
        |> put_resp_header("Freeflow", "FB")
        |> send_resp(:ok, response)
    end



	def request_user_password(conn, mobile_number, cmd, text, ussdRequests, passwordRequestMessage, client, clientTelco) do
		Logger.info text
		orginal_short_code = cmd


		activeStatus = "ACTIVE";
		query = from au in LoanSavingsSystem.Accounts.User, where: au.username == ^mobile_number and au.status == ^activeStatus, select: au
		companyStaff = Repo.one(query)

		if(!is_nil(companyStaff)) do
			checkMenu = String.split(text, "\*")
			checkMenuLength = Enum.count(checkMenu)
			IO.inspect checkMenu;

			Logger.info("request_user_password [[[[[[]]]]]]")
			Logger.info(checkMenuLength)

			if checkMenuLength==4 do
				#response = %{
				#	Message: passwordRequestMessage,
				#	ClientState: 1,
				#	Type: "Response",
				#	key: "CON"
				#}
				response = passwordRequestMessage

				send_response(conn, response)
			end
			if checkMenuLength>4 do
				valueEntered = Enum.at(checkMenu, (Enum.count(checkMenu)-2))
				Logger.info (valueEntered);
				handle_validate_password(conn, mobile_number, cmd, text, checkMenu, ussdRequests, valueEntered, client, clientTelco)
			end

		else
			#handle_new_account(conn, mobile_number, cmd, text)
			#response = %{
			#	Message: "Invalid profile. An active profile mapped to this number could not be found. \nContact MFZ staff to assist you with reactivating your profile",
			#	ClientState: 1,
			#	Type: "Response",
			#	key: "END"
			#}

			response = "Invalid profile. An active profile mapped to this number could not be found. \nContact MFZ staff to assist you with reactivating your profile";

			send_response(conn, response)
		end
	end

	def handle_validate_password(conn, mobile_number, cmd, text, checkMenu, ussdRequests, valueEntered, client, clientTelco) do

		activeStatus = "ACTIVE";
		query = from au in LoanSavingsSystem.Accounts.User, where: au.username == ^mobile_number, select: au
		loggedInUser = Repo.one(query)


		if(!is_nil(loggedInUser)) do

			if(loggedInUser.status != activeStatus) do
				#response = %{
				#	Message: "Your account is no longer active. Please contact LAXMI to reactivate your account. ",
				#	ClientState: 1,
				#	Type: "Response",
				#	key: "END"
				#}
				response = "Your account is no longer active. Please contact Microfinance Zambia to reactivate your account. "
				end_session(ussdRequests, conn, response);
			else
				passwordChecker = Base.encode16(:crypto.hash(:sha512, valueEntered))
				pwsdpin = String.trim_trailing(loggedInUser.pin, " ")
				passwordChecker1 = String.trim_trailing(pwsdpin, " ")
				IO.inspect "passwordChecker..."
				IO.inspect passwordChecker
				IO.inspect loggedInUser.pin
				IO.inspect passwordChecker1

				case String.equivalent?(passwordChecker, passwordChecker1) do
					false ->
						IO.inspect "loggedInUser.password_fail_count.."
						IO.inspect loggedInUser.password_fail_count
						
						if( is_nil(loggedInUser.password_fail_count)) do

							attrs = %{password_fail_count: 1}

							loggedInUser
							|> User.changeset(attrs)
							|> Repo.update()
							
							attrs = %{request_data: "*778#*"}
							ussdRequest = Enum.at(ussdRequests, 0);
							session_id = ussdRequest.session_id;

							ussdRequest
							|> UssdRequest.changeset(attrs)
							|> Repo.update()

							text = "\*778#\*"
							#request_user_password(conn, mobile_number, cmd, text, ussdRequests, "Invalid credentials. Please log in again. Your account will be locked if you fail to log in after 3 times\nb. Back \n0. End", client, clientTelco);
							response = "Invalid credentials. Please log in again. Your account will be locked if you fail to log in after 3 times\n\nb. Back \n0. End";

							send_response(conn, response)
							
						else
							if((loggedInUser.password_fail_count>1)) do
								attrs = %{password_fail_count: (loggedInUser.password_fail_count + 1), status: "BLOCKED"}

								loggedInUser
								|> User.changeset(attrs)
								|> Repo.update()
								
								attrs = %{request_data: "*778#*"}
								ussdRequest = Enum.at(ussdRequests, 0);
								session_id = ussdRequest.session_id;

								ussdRequest
								|> UssdRequest.changeset(attrs)
								|> Repo.update()

								text = "\*778#\*"
								#request_user_password(conn, mobile_number, cmd, text, ussdRequests, "Invalid credentials. Please log in again. Your account will be locked if you fail to log in after 3 times\nb. Back \n0. End", client, clientTelco);
								response = "Invalid credentials. Please log in again. Your account has been locked. Contact our customer support team for more assistance on this";

								send_response(conn, response)
								
							else
								attrs = %{password_fail_count: (loggedInUser.password_fail_count + 1)}

								loggedInUser
								|> User.changeset(attrs)
								|> Repo.update()
								
								attrs = %{request_data: "*778#*"}
								ussdRequest = Enum.at(ussdRequests, 0);
								session_id = ussdRequest.session_id;

								ussdRequest
								|> UssdRequest.changeset(attrs)
								|> Repo.update()

								text = "\*778#\*"
								#request_user_password(conn, mobile_number, cmd, text, ussdRequests, "Invalid credentials. Please log in again. Your account will be locked if you fail to log in after 3 times\nb. Back \n0. End", client, clientTelco);
								response = "Invalid credentials. Please log in again. Your account will be locked if you fail to log in after 3 times\n\nb. Back \n0. End";

								send_response(conn, response)
							end
						end


						

					true ->
						ussdRequest = Enum.at(ussdRequests, 0);
						session_id = ussdRequest.session_id;
						
						attrs = %{password_fail_count: 0, status: "ACTIVE"}

							loggedInUser
							|> User.changeset(attrs)
							|> Repo.update()

						Logger.info (ussdRequest.id);

						{1, [ussdRequest]} =
							from(p in UssdRequest, where: p.id == ^ussdRequest.id, select: p)
							|> Repo.update_all(set: [request_data: "*778#*", is_logged_in: 1]);


						text = "*778#*";
						query = from au in UssdRequest, where: au.mobile_number == ^mobile_number and au.session_id == ^session_id, select: au
						ussdRequests = Repo.all(query);
						welcome_menu(conn, mobile_number, cmd, text, client, clientTelco)
				end
			end

		else

			#response = %{
			#	Message: "Invalid credentials.",
			#	ClientState: 1,
			#	Type: "Response",
			#	key: "END"
			#}
			response = "Invalid credentials."
			end_session(ussdRequests, conn, response);
		end

	end


	def calculateCurrentBalance(conn, mobile_number, cmd, text, checkMenu, client, clientTelco) do
        query = from au in User,
			where: (au.username == type(^mobile_number, :string)),
			select: au
		appUsers = Repo.all(query);
		appUser = Enum.at(appUsers, 0);



		individualRoleType = "INDIVIDUAL"
		query = from au in LoanSavingsSystem.Accounts.UserRole,
			where: (au.userId == type(^appUser.id, :integer) and au.roleType == type(^individualRoleType, :string)),
			select: au
		userRoles = Repo.all(query);
		userRole = Enum.at(userRoles, 0);


		status = "Disbursed";
		isMatured = false
		isDivested = false
		query = from au in LoanSavingsSystem.FixedDeposit.FixedDeposits,
			where: (au.isMatured == type(^isMatured, :boolean) and au.isDivested == type(^isDivested, :boolean) and au.userId >= type(^appUser.id, :integer)),
			select: au
		fixedDeposits = Repo.all(query);
		totalBalance = 0.00;

			Logger.info "=========="
			Logger.info Enum.count(fixedDeposits)
			
		

		totalBalance = if Enum.count(fixedDeposits)>0 do

			#acc = Enum.reduce(fixedDeposits, fn x,
			#    acc -> x.id * acc
			#end)

			totals = for x <- 0..(Enum.count(fixedDeposits)-1) do
				#totalBalance = Enum.each(fixedDeposits, fn(fixedDeposit) ->
				fixedDeposit = Enum.at(fixedDeposits, x);


				query = from au in LoanSavingsSystem.Products.Product,
					where: (au.id == ^fixedDeposit.productId),
					select: au
				products = Repo.all(query);
				product = Enum.at(products, 0);

				period = 0;
				days = Date.diff(Date.utc_today, fixedDeposit.startDate)


				ntotals = calculate_maturity_repayments(fixedDeposit.principalAmount, days,
				   fixedDeposit.interestRate, fixedDeposit.yearLengthInDays, product.interestMode,
				   product.interestType, fixedDeposit.fixedPeriodType)
				Logger.info "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
				Logger.info ntotals
				ntotals
			end


			Logger.info Enum.count(totals)
			Logger.info "=========="
			totalBalance = Float.ceil(Enum.sum(totals), client.defaultCurrencyDecimals)
			totalBalance
		else
			totalBalance = 0.00
			totalBalance
		end
		totalBalance
    end
	
	
	def checkIfFloat(v) do
		
		
		v = case Float.parse(v) do
			{v, u} ->
				IO.inspect "v...#{v}"
				IO.inspect v
				v
			error ->
				v = case Integer.parse(v) do
					{v, u} ->
						IO.inspect "v1..."
						IO.inspect v
						v
					error ->
						IO.inspect "error..."
						IO.inspect error

						false
				end
		end
		
		v
	end
	
	
	def checkIfInteger(v) do
		
		
		v = case Integer.parse(v) do
			{v, u} ->
				v
			error ->
				false
		end
		
		v
	end
	
	
	def rsaEncryptDataForAirtel(data) do
	
		pubkey = "-----BEGIN PUBLIC KEY-----\r\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCkq3XbDI1s8Lu7SpUBP+bqOs/MC6PKWz\r\n6n/0UkqTiOZqKqaoZClI3BUDTrSIJsrN1Qx7ivBzsaAYfsB0CygSSWay4iyUcnMVEDrNVO\r\nJwtWvHxpyWJC5RfKBrweW9b8klFa/CfKRtkK730apy0Kxjg+7fF0tB4O3Ic9Gxuv4pFkbQ\r\nIDAQAB\r\n-----END PUBLIC KEY----"

		#pubkey = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCkq3XbDI1s8Lu7SpUBP+bqOs/MC6PKWz6n/0UkqTiOZqKqaoZClI3BUDTrSIJsrN1Qx7ivBzsaAYfsB0CygSSWay4iyUcnMVEDrNVOJwtWvHxpyWJC5RfKBrweW9b8klFa/CfKRtkK730apy0Kxjg+7fF0tB4O3Ic9Gxuv4pFkbQIDAQAB"

		#pubkey = File.read!("priv/cert/pubkey.pem")
		IO.inspect pubkey
		[enc_p_key] = :public_key.pem_decode(pubkey)
		IO.inspect enc_p_key
		p_key = :public_key.pem_entry_decode(enc_p_key)
		IO.inspect p_key
		enc_msg = :public_key.encrypt_public(data, p_key)
		enc_msg = Base.encode64(enc_msg)
		IO.inspect enc_msg;
		enc_msg;
	end
	
	
	def rsaEncryptDataForAirtelOld(data) do
	
		pubkey = "-----BEGIN PUBLIC KEY-----\r\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCkq3XbDI1s8Lu7SpUBP+bqOs/MC6PKWz\r\n6n/0UkqTiOZqKqaoZClI3BUDTrSIJsrN1Qx7ivBzsaAYfsB0CygSSWay4iyUcnMVEDrNVO\r\nJwtWvHxpyWJC5RfKBrweW9b8klFa/CfKRtkK730apy0Kxjg+7fF0tB4O3Ic9Gxuv4pFkbQ\r\nIDAQAB\r\n-----END PUBLIC KEY----"

		#pubkey = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCkq3XbDI1s8Lu7SpUBP+bqOs/MC6PKWz6n/0UkqTiOZqKqaoZClI3BUDTrSIJsrN1Qx7ivBzsaAYfsB0CygSSWay4iyUcnMVEDrNVOJwtWvHxpyWJC5RfKBrweW9b8klFa/CfKRtkK730apy0Kxjg+7fF0tB4O3Ic9Gxuv4pFkbQIDAQAB"

		#pubkey = File.read!("priv/cert/pubkey.pem")
		IO.inspect pubkey
		[enc_p_key] = :public_key.pem_decode(pubkey)
		IO.inspect enc_p_key
		p_key = :public_key.pem_entry_decode(enc_p_key)
		IO.inspect p_key
		now_str = DateTime.utc_now() |> DateTime.to_unix(:millisecond) |> Integer.to_string()
		login_msg = Base.encode64("000") <> ":" <> Base.encode64("000") <> ":" <> Base.encode64(now_str)
		enc_msg = :public_key.encrypt_public(login_msg, p_key)
		enc_msg = Base.encode64(enc_msg)
		IO.inspect enc_msg;
		enc_msg;
	end
	
	
end
