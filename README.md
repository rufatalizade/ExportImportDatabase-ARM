## This article is about creating two Azure SQL Server/DB then export/import from first one to second.

#### This readme include explanation "Deploy-AzureResourceGroup.ps1" file (starting from 120 line). Before 120 line, script includes Microsoft official ARM deploy.


### For working with AzureSQL we have to install SqlServer module. 
```powershell 
Install-module -Name SqlServer -Scope CurrentUser
```

### This command gets result of ARM deployment from Azure. This give us ability to retrieve the the needed string for next actions. The below output shows every time you deployes JSON template. But, to continue script upon this output we should again retrieve this output. To do this, run the following command: 
```powershell
$lastRgDeployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName  $ResourceGroupName | Sort-Object Timestamp -Descending | Select-Object -First 1 
```

### This output is not 'here-string' and we can retrieve the needed elements. the output:
```powershell
DeploymentName          : azuredeploy-0523-1701
ResourceGroupName       : RMTwoDatabase0
ProvisioningState       : Succeeded
Timestamp               : 5/23/2018 5:04:23 PM
Mode                    : Incremental
TemplateLink            : 
Parameters              : 
                          Name             Type                       Value     
                          ===============  =========================  ==========
                          rasql01AdminLogin  String                     sqladmin  
                          rasql01AdminLoginPassword  SecureString                         
                          rasql02AdminLogin  String                     sqladmin  
                          rasql02AdminLoginPassword  SecureString                         
                          rasqldb01Name    String                     dbname01  
                          rasqldb01Collation  String                     SQL_Latin1_General_CP1_CI_AS
                          rasqldb01Edition  String                     Basic     
                          rasqldb01RequestedServiceObjectiveName  String                     Basic     
                          rasqldb02Name    String                     dbname02  
                          rasqldb02Collation  String                     SQL_Latin1_General_CP1_CI_AS
                          rasqldb02Edition  String                     Basic     
                          rasqldb02RequestedServiceObjectiveName  String                     Basic     
                          
Outputs                 : 
                          Name             Type                       Value     
                          ===============  =========================  ==========
                          sql1ServerName   String                     rasql01yqz4r3xksiddc.database.windows.net
                          sql2ServerName   String                     rasql02yqz4r3xksiddc.database.windows.net
                          
DeploymentDebugLogLevel : 
```

### The following commands retrieves the deployed SQL Servername,DB name, user/pass:
```powershell
$firstSQlServer = ($lastRgDeployment.Outputs.Values).Value[0]
$secondSQlServer = ($lastRgDeployment.Outputs.Values).Value[1]
$firstDBName = $lastRgDeployment.Parameters.rasqldb01Name.Value
$secondDBName = $lastRgDeployment.Parameters.rasqldb02Name.Value
$firstCS = "server='$firstSQlServer';database='$firstDBName';trusted_connection=true;"
$firstCS = "server='$secondSQlServer';database='$secondDBName';trusted_connection=true;"
```

### output of above variables:
```powershell
rasql01yqz4r3xksiddc.database.windows.net
rasql02yqz4r3xksiddc.database.windows.net
dbname01
dbname02
server='rasql01yqz4r3xksiddc.database.windows.net';database='dbname01';trusted_connection=true;
server='rasql02yqz4r3xksiddc.database.windows.net';database='dbname02';trusted_connection=true;
```

### This command get content of json parameter as string (text) then it convert to JSON object type variable where you can access specific elements (parameters in this case)
```powershell
$JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
$sqlusername = $JsonParameters.parameters.rasql01AdminLogin.value
$sqlAdminpass = $JsonParameters.parameters.rasql01AdminLoginPassword.value
```

### Convert the password to secure string (the password which was taken from JSON parameter, see previous section.)
```powershell
$pwd = ConvertTo-SecureString "$($sqlAdminpass)" -AsPlainText -Force
```

### Takes my public IP address from internet. To access AzureSQL and manage it  (connection,invoking and modifying directly DBs) we need add our PublicIP address to SQLServer firewall exception rule. This could  be done while deploying JSON also (set parameters in properties, under 'resource'.)
```powershell
[string]$myip = ((Invoke-WebRequest -Uri http://ipconfig.io/ip).Content).Trim() 
```  

### To add PublicIP to SQLServer firewall exception, run the following command:
```powershell
New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $firstSQlServer.Split('.')[0] -FirewallRuleName 'Rule1' -StartIpAddress $myip -EndIpAddress $myip
New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $secondSQlServer.Split('.')[0] -FirewallRuleName 'Rule2' -StartIpAddress $myip -EndIpAddress $myip
```

### Beside creation the SQL servers this script creates the table with two columns and inserts test rows and at the end of the script, it exports this the table (from first sql server) as blob file to storage container then restore it into second sql server. The following just 'here-text' variabe for querying in AzureSQL server:
```powershell
$Query01 = 
@"       
        CREATE TABLE [TABLE01] (
        [poshID] [int] IDENTITY(1,1) NOT NULL,
        [objectTypeName] [nvarchar](100),
            CONSTRAINT [PK_COLUMNID] PRIMARY KEY CLUSTERED 
        (
        [poshID] ASC
        )WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
        ) ON [PRIMARY] 
"@

$Query02 = 
@"
INSERT INTO [dbname01].dbo.[TABLE01] (objectTypeName)
        VALUES ('test')
"@
```

### Invoking the above SQL queries in first SQL server:
```powershell
foreach ($query in @($Query01, $Query02)) {
    Invoke-SqlCmd -Username "$sqlusername" -Password "$sqlAdminpass" -ServerInstance $firstSQlServer -Database $firstDBName -Query $query
}
```

### This command creates the storage account under specified resource group:
```powershell
New-AzureRmStorageAccount -ResourceGroupName $resourcegroupname -AccountName $StorageAccountName -Location $location  -SkuName "Standard_LRS" -Kind Storage
```

### This command gets key from newly created storage account key (key (or permission) is needed for accessing and do actions under this storage account): 
```powershell
$accountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourcegroupname -Name $StorageAccountName).Value[0]
```

### This command create context under storage account (context (or link) is set of informations, in this case its create and show about blob,table,file endpoint)
```powershell
$context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $accountKey
```
### output:
```powershell
StorageAccountName : strgaccname
BlobEndPoint       : https://strgaccname.blob.core.windows.net/
TableEndPoint      : https://strgaccname.table.core.windows.net/
QueueEndPoint      : https://strgaccname.queue.core.windows.net/
FileEndPoint       : https://strgaccname.file.core.windows.net/
Context            : Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext
Name               : 
StorageAccount     : BlobEndpoint=https://strgaccname.blob.core.windows.net/;QueueEndpoint=https://strgaccname.queue.core.windows.net/;TableEndpoint=https://strgaccname.table.core.windows.net/;F
                     ileEndpoint=https://strgaccname.file.core.windows.net/;AccountName=strgaccname;AccountKey=[key hidden]
EndPointSuffix     : core.windows.net/
ConnectionString   : BlobEndpoint=https://strgaccname.blob.core.windows.net/;QueueEndpoint=https://strgaccname.queue.core.windows.net/;TableEndpoint=https://strgaccname.table.core.windows.net/;F
                     ileEndpoint=https://strgaccname.file.core.windows.net/;AccountName=strgaccname;AccountKey=L1EWNllbmB6A9bRqnBsegw40LtRmzYVq5cZMUW0rSW0fBvEu0YzLAjru5Uk++am3OZGJ9T/VerSKJWX0toG
                     HkA==
ExtendedProperties : {}
```

### This command creates the container (think like a folder) based on context created for storage account:
```powershell
New-AzureStorageContainer -Name $StorageContainerName -Context $context -Permission Container  
```

### There might be some delays when you create/update or upload some item to Azure. To avoid this, scripts waiting until it get item from Azure.
```powershell
while (!(Get-AzureStorageContainer -Name "$($ResourceGroupName.ToLower())*" -Context $context -ErrorAction SilentlyContinue).Name) {
    Write-Host "Container still not exist in storage container" -ForegroundColor Yellow
    start-sleep 20
}
```

### After container created, the following command export  Database from  first sql server and put it to container: 
```powershell
New-AzureRmSqlDatabaseExport -ResourceGroupName $resourcegroupname `
    -ServerName $firstSQlServer.Split('.')[0] `
    -DatabaseName $firstDBName `
    -StorageKeyType "StorageAccessKey" `
    -StorageKey $accountKey `
    -StorageUri "$($context.BlobEndPoint)$StorageContainerName/$firstDBName.bacpac" `
    -AdministratorLogin $sqlusername -AdministratorLoginPassword $pwd
```
### The output of StorageUri variable is: 
```powershell
https://strgaccname.blob.core.windows.net/rmtwodatabase0-stageartifacts/dbname01.bacpac
```

### The following command waits until it gets filename from Azure (as mentioned early, there might be some delay after script put the blob file)
```powershell
while (!(Get-AzureStorageBlob -Container $StorageContainerName  -Context $context -Blob "$($firstDBName.Substring(0,3))*"  -ErrorAction SilentlyContinue)) {
    Write-Host "Blob file or container still not exist in storage container" -ForegroundColor Yellow
    start-sleep 60
}
```

### At the end, we import backed up database to second SQL server:
```powershell
New-AzureRmSqlDatabaseImport -ResourceGroupName $resourcegroupname `
    -ServerName $secondSQlServer.Split('.')[0] `
    -DatabaseName $firstDBName `
    -StorageKeyType "StorageAccessKey" `
    -StorageKey $accountKey `
    -StorageUri  "$($context.BlobEndPoint)$StorageContainerName/$firstDBName.bacpac"`
    -AdministratorLogin $sqlusername -AdministratorLoginPassword $pwd `
    -Edition Standard -ServiceObjectiveName S0 -DatabaseMaxSizeBytes 5000000
```
