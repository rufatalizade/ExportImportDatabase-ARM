#Requires -Version 3.0
Param(
    [string] $ResourceGroupLocation = 'westeurope',
    [string] $ResourceGroupName = 'RMTwoDatabase0',
    [switch] $UploadArtifacts,
    [string] $location = "WestEurope",
    [string] $StorageAccountName = 'strgaccname',
    [string] $StorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts',
    [string] $TemplateFile = 'azuredeploy.json',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.json',
    [string] $ArtifactStagingDirectory = '.',
    [string] $DSCSourceFolder = 'DSC',
    [switch] $ValidateOnly
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ', '_'), '3.0.0')
}
catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
    $JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
    if (($JsonParameters | Get-Member -Type NoteProperty 'parameters') -ne $null) {
        $JsonParameters = $JsonParameters.parameters
    }
    $ArtifactsLocationName = '_artifactsLocation'
    $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'
    $OptionalParameters[$ArtifactsLocationName] = $JsonParameters | Select -Expand $ArtifactsLocationName -ErrorAction Ignore | Select -Expand 'value' -ErrorAction Ignore
    $OptionalParameters[$ArtifactsLocationSasTokenName] = $JsonParameters | Select -Expand $ArtifactsLocationSasTokenName -ErrorAction Ignore | Select -Expand 'value' -ErrorAction Ignore

    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {
        $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object -Process {$_.FullName})
        foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
            $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + '.zip'
            Publish-AzureRmVMDscConfiguration $DSCSourceFilePath -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
    }

    # Create a storage account name if none was provided
    if ($StorageAccountName -eq '') {
        $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
    }

    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName})

    # Create the storage account if it doesn't already exist
    if ($StorageAccount -eq $null) {
        $StorageResourceGroupName = 'ARM_Deploy_Staging'
        New-AzureRmResourceGroup -Location "$ResourceGroupLocation" -Name $StorageResourceGroupName -Force
        $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$ResourceGroupLocation"
    }

    # Generate the value for artifacts location if it is not provided in the parameter file
    if ($OptionalParameters[$ArtifactsLocationName] -eq $null) {
        $OptionalParameters[$ArtifactsLocationName] = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
    }

    # Copy files from the local storage staging location to the storage account container
    New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1

    $ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        Set-AzureStorageBlobContent -File $SourcePath -Blob $SourcePath.Substring($ArtifactStagingDirectory.length + 1) `
            -Container $StorageContainerName -Context $StorageAccount.Context -Force
    }

    # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file
    if ($OptionalParameters[$ArtifactsLocationSasTokenName] -eq $null) {
        $OptionalParameters[$ArtifactsLocationSasTokenName] = ConvertTo-SecureString -AsPlainText -Force `
        (New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4))
    }
}

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

if ($ValidateOnly) {
    $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $TemplateParametersFile `
            @OptionalParameters)
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }
}
else {
    New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $TemplateParametersFile `
        @OptionalParameters `
        -Force -Verbose `
        -ErrorVariable ErrorMessages 
    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    } 
}

Install-module -Name SqlServer -Scope CurrentUser

$lastRgDeployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName  $ResourceGroupName | Sort-Object Timestamp -Descending | Select-Object -First 1 
$firstSQlServer = ($lastRgDeployment.Outputs.Values).Value[0]
$secondSQlServer = ($lastRgDeployment.Outputs.Values).Value[1]
$firstDBName = $lastRgDeployment.Parameters.rasqldb01Name.Value
$secondDBName = $lastRgDeployment.Parameters.rasqldb02Name.Value
$firstCS = "server='$firstSQlServer';database='$firstDBName';trusted_connection=true;"
$firstCS = "server='$secondSQlServer';database='$secondDBName';trusted_connection=true;"

$JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
$sqlusername = $JsonParameters.parameters.rasql01AdminLogin.value
$sqlAdminpass = $JsonParameters.parameters.rasql01AdminLoginPassword.value
$pwd = ConvertTo-SecureString "$($sqlAdminpass)" -AsPlainText -Force

[string]$myip = ((Invoke-WebRequest -Uri http://ipconfig.io/ip).Content).Trim() 

New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $firstSQlServer.Split('.')[0] -FirewallRuleName 'Rule1' -StartIpAddress $myip -EndIpAddress $myip
New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $secondSQlServer.Split('.')[0] -FirewallRuleName 'Rule2' -StartIpAddress $myip -EndIpAddress $myip

#   Create new table under SQLServer01 database
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

foreach ($query in @($Query01, $Query02)) {
    Invoke-SqlCmd -Username "$sqlusername" -Password "$sqlAdminpass" -ServerInstance $firstSQlServer -Database $firstDBName -Query $query
}

New-AzureRmStorageAccount -ResourceGroupName $resourcegroupname -AccountName $StorageAccountName -Location $location  -SkuName "Standard_LRS" -Kind Storage
$accountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourcegroupname -Name $StorageAccountName).Value[0]

$context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $accountKey 

New-AzureStorageContainer -Name $StorageContainerName -Context $context -Permission Container  

#before export database into the container, check if Storage Container exist
while (!(Get-AzureStorageContainer -Name "$($ResourceGroupName.ToLower())*" -Context $context -ErrorAction SilentlyContinue).Name) {
    Write-Host "Container still not exist in storage container" -ForegroundColor Yellow
    start-sleep 20
}

New-AzureRmSqlDatabaseExport -ResourceGroupName $resourcegroupname `
    -ServerName $firstSQlServer.Split('.')[0] `
    -DatabaseName $firstDBName `
    -StorageKeyType "StorageAccessKey" `
    -StorageKey $accountKey `
    -StorageUri "$($context.BlobEndPoint)$StorageContainerName/$firstDBName.bacpac" `
    -AdministratorLogin $sqlusername -AdministratorLoginPassword $pwd

                             
   
#after exported  dlob files (db in this case),  check if   files really exist there, it takes some minutre. 
while (!(Get-AzureStorageBlob -Container $StorageContainerName  -Context $context -Blob "$($firstDBName.Substring(0,3))*"  -ErrorAction SilentlyContinue)) {
    Write-Host "Blob file or container still not exist in storage container" -ForegroundColor Yellow
    start-sleep 60
}

New-AzureRmSqlDatabaseImport -ResourceGroupName $resourcegroupname `
    -ServerName $secondSQlServer.Split('.')[0] `
    -DatabaseName $firstDBName `
    -StorageKeyType "StorageAccessKey" `
    -StorageKey $accountKey `
    -StorageUri  "$($context.BlobEndPoint)$StorageContainerName/$firstDBName.bacpac"`
    -AdministratorLogin $sqlusername -AdministratorLoginPassword $pwd `
    -Edition Standard -ServiceObjectiveName S0 -DatabaseMaxSizeBytes 5000000


