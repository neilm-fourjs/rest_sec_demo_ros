
IMPORT com

CONSTANT C_CON_TIMEOUT = 5

PUBLIC DEFINE m_headers DYNAMIC ARRAY OF RECORD
	key STRING,
	val STRING,
	addToSig BOOLEAN
	END RECORD
--------------------------------------------------------------------------------
-- Make a restful WS call and return the status and text reply
--
-- GET doesn't need Digest or X-HTTP-Method-Override,  POST does require a Digest
--
-- @param l_method GET / POST
-- @param l_url The URL for the request
-- @param l_signature To sign the request
-- @param l_payload for the POST request
-- @returns status & reply-text - status -1 = failed to do request
FUNCTION do_rest_request(l_method STRING, l_url STRING, l_signature STRING, l_payload STRING )
							RETURNS ( SMALLINT, STRING )
	DEFINE l_req com.HttpRequest
	DEFINE l_resp com.HTTPResponse
	DEFINE l_info RECORD
		status SMALLINT,
		header STRING
	END RECORD
	DEFINE x SMALLINT
	DEFINE l_txt STRING

	CALL disp(SFMT("Create '%1'  ...",l_url))
	LET l_req = com.HttpRequest.Create(l_url)
	CALL disp(SFMT("setMethod %1 ...",l_method))
	CALL l_req.setMethod(l_method)

	CALL disp("setHeaders ...")
	FOR x = 2 TO m_headers.getLength()
		CALL disp( SFMT("setHeader(%1,%2)",m_headers[x].key, m_headers[x].val) )
		CALL l_req.setHeader(m_headers[x].key, m_headers[x].val)
	END FOR
	CALL disp( SFMT("setHeader(%1,%2)","Signature", l_signature) )
	CALL l_req.setHeader("Signature",l_signature)
	CALL l_req.setConnectionTimeOut( C_CON_TIMEOUT )
	IF l_method = "GET" THEN
		CALL disp("doRequest ...")
		TRY
			CALL l_req.doRequest()
		CATCH
			LET l_txt = "Failed to doRequest for "||l_url||" "||STATUS||" "||ERR_GET(STATUS)
			CALL disp( l_txt  )
			RETURN -1, l_txt
		END TRY
	ELSE
		CALL disp(SFMT("doTextRequest('%1') ...",l_payload))
		TRY
			CALL l_req.doTextRequest( l_payload )
		CATCH
			LET l_txt = "Failed to doTextRequest for "||l_url||" "||STATUS||" "||ERR_GET(STATUS)
			CALL disp( l_txt  )
			RETURN -1, l_txt
		END TRY
	END IF

	CALL disp("getResponse ...")
	TRY
		LET l_resp = l_req.getResponse()
	CATCH
		LET l_txt =  "Failed to getResponse for "||l_url||" "||STATUS||" "||ERR_GET(STATUS)
		CALL disp( l_txt )
		RETURN -1, l_txt
	END TRY

	LET l_info.status = l_resp.getStatusCode()
	IF l_info.status != 200 THEN
		CALL disp( "Failed:"|| l_info.status )
--		RETURN
	ELSE
		CALL disp( "Success!" )
	END IF

	LET l_info.header = l_resp.getHeader("Content-Type")
	CALL disp( "StatusCode:"||l_info.status )
	CALL disp( "Header:"||l_info.header )
	LET l_txt = l_resp.getTextResponse()
	CALL disp( "Response:"||l_txt )

	RETURN l_info.status, l_txt 
END FUNCTION
--------------------------------------------------------------------------------
-- Build array of HTTP Headers
--
-- @param l_key Key for header, eg: X-Date
-- @param l_val Value for the header
-- @param l_addToSig Boolean to say if the head is part of the signature
FUNCTION arr_addItem(l_key STRING,l_val STRING, l_addToSig BOOLEAN)
	LET m_headers[m_headers.getLength()+1].key = l_key
	LET m_headers[m_headers.getLength()].val = l_Val
	LET m_headers[m_headers.getLength()].addToSig = l_addToSig
END FUNCTION
--------------------------------------------------------------------------------