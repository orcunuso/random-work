$SQLServer = ""
$SQLDBName = ""
$SqlQuery = "select COUNT(*) from VPX_EVENT_ARG"

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"

$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $SqlQuery
$SqlCmd.Connection = $SqlConnection

$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter.SelectCommand = $SqlCmd

$DataSet = New-Object System.Data.DataSet
$SqlAdapter.Fill($DataSet)
 
$SqlConnection.Close()

$DataSet.Tables[0] | FT -AutoSize