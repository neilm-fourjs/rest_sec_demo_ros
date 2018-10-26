
IMPORT util
IMPORT com
IMPORT security

IMPORT FGL getBase64Cert
IMPORT FGL generateSignature
IMPORT FGL encrypt
IMPORT FGL compute_digest
IMPORT FGL lib_log

IMPORT FGL do_rest_request

CONSTANT C_SOFTWARE = "FourJsTest"
CONSTANT C_SOFTWAREVER = "0.1"
CONSTANT C_TZ = "GMT"

CONSTANT C_HOST = "softwaretest.ros.ie"

DEFINE m_cert, m_empRegNo, m_taxYear STRING
MAIN
	DEFINE l_reqTarget STRING
	DEFINE l_reply STRING
	DEFINE l_stat SMALLINT

	LET m_cert = "../certs/999962922"
	LET m_empRegNo = "8001274QH"
	LET m_taxYear = "2018"

	OPEN FORM frm FROM "testConnect"
	DISPLAY FORM frm

	DISPLAY ARRAY do_rest_request.m_headers TO scr_arr.* ATTRIBUTES( ACCEPT=FALSE, CANCEL=FALSE )
		ON ACTION close EXIT DISPLAY
		ON ACTION exit EXIT DISPLAY
		ON ACTION get_emps
			LET l_reqTarget = SFMT("paye-employers/v1/rest/rpn/%1/%2?softwareUsed=%3&softwareVersion=%4", m_empRegNo, m_taxYear, C_SOFTWARE, C_SOFTWAREVER )
			CALL test1( l_reqTarget, NULL ) RETURNING l_stat, l_reply
			IF l_stat = 200 THEN
				CALL process_rpn( l_reply )
			END IF
		ON ACTION add_emp CALL add_emp()
	END DISPLAY

END MAIN
--------------------------------------------------------------------------------
FUNCTION test1( l_reqTarget STRING, l_payload STRING )
	DEFINE x SMALLINT
	DEFINE l_method STRING
	DEFINE l_signature, l_date, l_signed STRING
	DEFINE l_url, l_keyId, l_headers STRING
	DEFINE l_reply STRING
	DEFINE l_stat SMALLINT

	CALL disp("Starting test1 ...")

	LET l_method = "GET"
	LET l_url = SFMT("https://%1/%2",C_HOST, l_reqTarget)

	CALL disp(SFMT("Get the base64 version of '%1'", m_cert||".pem"))
	LET l_keyId = getBase64Cert.getBase64Cert(m_cert||".pem")
	LET l_date = util.Datetime.format( util.Datetime.getCurrentAsUTC(), "%a, %d %b %Y %H:%M:%S "||C_TZ)
-- Fri, 12 Oct 2018 15:42:54 GMT   -- no way to get the Timezone?
--	LET l_date = util.Datetime.format( CURRENT, "%a %d %b %Y %H:%M:%S "||C_TZ)
	IF l_payload.getLength() > 1 THEN
		LET l_method = "POST"
	END IF

	CALL do_rest_request.m_headers.clear()
	CALL do_rest_request.arr_addItem("(request-target)", SFMT("%1 /%2",l_method.toLowerCase(), l_reqTarget), TRUE)
	CALL do_rest_request.arr_addItem( "Host", C_HOST, TRUE)

--	CALL arr_addItem( "Date", l_date, TRUE) -- Date can't be set manually!!
	CALL do_rest_request.arr_addItem( "X-Date", l_date, TRUE)

	IF l_method = "POST" THEN
--		CALL arr_addItem( "X-HTTP-Method-Override","GET", TRUE)
		CALL do_rest_request.arr_addItem( "Digest", compute_digest.ComputeHash(l_payload,"sha512"), TRUE )
		--CALL arr_addItem( "Content-Type","application/x-www-form-urlencoded", FALSE)
		CALL do_rest_request.arr_addItem( "Content-Type","application/json", FALSE)
	END IF

	FOR x = 1 TO do_rest_request.m_headers.getLength()
		IF do_rest_request.m_headers[x].addToSig THEN
			IF x > 1 THEN LET l_headers = l_headers.append(" ") END IF
			LET l_headers = l_headers.append(do_rest_request.m_headers[x].key.toLowerCase())
		END IF
	END FOR

	LET l_signed = generateSignature.fromArray( do_rest_request.m_headers )

	CALL disp("URL: "||l_url)
	CALL disp("KeyId: "||l_keyId)
	CALL disp("Headers: "||l_headers)
	CALL disp("Date: "||l_date)
	CALL disp("To Sign: \n"||l_signed)
	DISPLAY BY NAME l_url, l_headers, l_date, l_keyId, l_signed
	DISPLAY ARRAY do_rest_request.m_headers TO scr_arr.*
		BEFORE DISPLAY EXIT DISPLAY
	END DISPLAY

	CALL disp(SFMT("Get encrypted sig using private key '%1'",m_cert||".signkey") )
	LET l_signed = encrypt.withKeyFile( l_signed, m_cert||".signkey")
	LET l_signature = SFMT('keyId="%1",algorithm="%2",headers="%3",signature="%4"',
					l_keyId, "rsa-sha512",l_headers, l_signed)

	CALL disp("Signed: "||l_signed)
	CALL disp("Signature: "||l_signature)
	DISPLAY "\n\n\n"

	CALL do_rest_request(l_method, l_url, l_signature, l_payload) RETURNING l_stat, l_reply

	DISPLAY BY NAME l_reply
	CALL disp("Finished test1.")
	RETURN l_stat, l_reply
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION process_rpn( l_reply STRING )
	DEFINE x SMALLINT
	DEFINE l_json_data TEXT
	DEFINE l_rpn  RECORD
		employerName STRING,
		employerRegistrationNumber STRING,
		taxYear FLOAT,
		totalRPNCount FLOAT,
		dateTimeEffective STRING,
		rpns DYNAMIC ARRAY OF RECORD
			rpnNumber STRING,
			employeeID RECORD
				employeePpsn STRING,
				employmentID STRING
				END RECORD,
			rpnIssueDate STRING,
			employerReference STRING,
			name RECORD
				firstName STRING,
				familyName STRING
			END RECORD,
				effectiveDate STRING,
				endDate STRING,
				incomeTaxCalculationBasis STRING,
				exclusionOrder BOOLEAN,
				yearlyTaxCredits FLOAT,
				taxRates DYNAMIC ARRAY OF RECORD
				index FLOAT,
				taxRatePercent FLOAT,
				yearlyRateCutOff FLOAT
			END RECORD,
				payForIncomeTaxToDate FLOAT,
				incomeTaxDeductedToDate FLOAT,
				uscStatus STRING,
				uscRates DYNAMIC ARRAY OF RECORD
					index FLOAT,
					uscRatePercent FLOAT,
					yearlyUSCRateCutOff FLOAT
				END RECORD
			END RECORD
		END RECORD

	LOCATE l_json_data IN FILE "rpn.json"
	LET l_json_data = util.JSON.format( l_reply )

	CALL util.JSON.parse( l_reply, l_rpn )

	DISPLAY "Data:"
	DISPLAY l_rpn.employerName
	FOR x = 1 TO l_rpn.rpns.getLength()
		DISPLAY l_rpn.rpns[x].employeeID.employeePpsn,":",l_rpn.rpns[x].name.familyName," ",l_rpn.rpns[x].name.firstName
	END FOR

END FUNCTION
--------------------------------------------------------------------------------
-- 
FUNCTION add_emp()
	DEFINE dummy RECORD
		requestId STRING,
		newEmployeeDetails DYNAMIC ARRAY OF RECORD
			employeePpsn STRING,
			employeeID STRING,
			name RECORD
				firstName STRING,
				familyName STRING
			END RECORD,
			employmentStartDate DATE
		END RECORD
	END RECORD
	DEFINE l_payload, l_reqTarget STRING
	DEFINE l_reply STRING
	DEFINE l_stat SMALLINT

	OPEN WINDOW w1 WITH FORM "new_emp"
	LET int_flag = FALSE
	LET dummy.requestId = security.RandomGenerator.CreateUUIDString()
	LET dummy.newEmployeeDetails[1].employeeID = 1
	LET dummy.newEmployeeDetails[1].employeePpsn = "7027010WA"
	LET dummy.newEmployeeDetails[1].name.firstName = "Ralph"
	LET dummy.newEmployeeDetails[1].name.familyName = "Johnston"
	LET dummy.newEmployeeDetails[1].employmentStartDate = TODAY

	INPUT BY NAME dummy.newEmployeeDetails[1].employeeID, 
								dummy.newEmployeeDetails[1].employeePpsn,
								dummy.newEmployeeDetails[1].name.firstName,
								dummy.newEmployeeDetails[1].name.familyName,
								dummy.newEmployeeDetails[1].employmentStartDate WITHOUT DEFAULTS

	CLOSE WINDOW w1

	IF int_flag THEN RETURN END IF

	LET l_payload = util.JSON.stringify( dummy )
	DISPLAY "Payload: ",l_payload

	LET l_reqTarget = SFMT("paye-employers/v1/rest/rpn/%1/%2?softwareUsed=%3&softwareVersion=%4", m_empRegNo, m_taxYear, C_SOFTWARE, C_SOFTWAREVER )
	CALL test1( l_reqTarget, l_payload ) RETURNING l_stat, l_reply

END FUNCTION
