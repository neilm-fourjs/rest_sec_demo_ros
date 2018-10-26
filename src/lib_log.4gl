DEFINE m_txt STRING
--------------------------------------------------------------------------------
FUNCTION log(l_txt STRING)
	DEFINE c base.channel
	LET c = base.Channel.create()
	CALL c.openFile( base.application.getProgramName()||".log","a+")
	CALL c.writeLine(l_txt)
	CALL C.close()
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION disp(l_txt STRING)
	DISPLAY l_txt
	LET l_txt = CURRENT||":"||l_txt
	CALL log(l_txt)
	LET m_txt = m_txt.append( l_txt||"\n" )
	DISPLAY BY NAME m_txt
	CALL ui.Interface.refresh()
END FUNCTION