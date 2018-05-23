### List storage account in the subcscription:
```powershell 
PS C:\PowerShell> Get-AzureRMStorageAccount | Select StorageAccountName
, Location
StorageAccountName       Location
------------------       --------
cs17739e5e8222ax46c5xb26 southeastasia
```

### Note: If you want to remove Azure Storage account then use the following command:
```powershell
PS C:\PowerShell> Remove-AzureRmStorageAccount -ResourceGroupName "jsRG" -StorageAccountName $storageAccountName
Confirm
Remove Storage Account 'jspshstorage' and all content in it
[Y] Yes  [N] No  [S] Suspend  [?] Help (default is "Y"): Y
```

### Use an existing storage account:
```powershell
PS C:\PowerShell> $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName
```

### Set location and resource group name. Create Resource Group in the selected location:
```powershell
PS C:\PowerShell> $location = "westeurope"
PS C:\PowerShell> $resourceGroup = "jsRG"
PS C:\PowerShell> New-AzureRmResourceGroup -Name $resourceGroup -Location $location
ResourceGroupName : jsRG
Location          : westeurope
ProvisioningState : Succeeded
Tags              :
ResourceId        : /subscriptions/7739e5e8-222a-46c5-b26f-5d7191b4e5b
                    6/resourceGroups/jsRG
```

### Set storage account name and SKU name (Note Storage account name can be only with lower letters):
```powershell
PS C:\PowerShell> $storageAccountName = "jspshstorage"
PS C:\PowerShell> $skuName = "Standard_LRS"
```

### Create the new storage account:
```powershell
PS C:\PowerShell> $storageAccount = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName -Location $location -SkuName $skuName -Kind Storage -EnableEncryptionService Blob -AccessTier Hot
```

#### or:
```powershell
PS C:\PowerShell> $storageAccount = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -AccountName $storageAccountName -Location $location -SkuName $skuName -Kind Storage -EnableEncryptionService "Blob,File" -AssignIdentity
```

#### Or: 
```powershell
$StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$ResourceGroupLocation"
```

### Get content of the storage Account:
```powershell
PS C:\PowerShell> $ctx = $storageAccount.Context
PS C:\PowerShell> $ctx
BlobEndPoint       : https://jspshstorage.blob.core.windows.net/
TableEndPoint      : https://jspshstorage.table.core.windows.net/
QueueEndPoint      : https://jspshstorage.queue.core.windows.net/
FileEndPoint       : https://jspshstorage.file.core.windows.net/
StorageAccount     : BlobEndpoint=https://jspshstorage.blob.core.windows.net/;QueueEndpoint=https://jspshstorage.queue.core.windows.ne
                     t/;TableEndpoint=https://jspshstorage.table.core.windows.net/;FileEndpoint=https://jspshstorage.file.core.windows
                     .net/;AccountName=jspshstorage;AccountKey=[key hidden]
StorageAccountName : jspshstorage
Context            : Microsoft.WindowsAzure.Commands.Common.Storage.LazyAzureStorageContext
Name               : jspshstorage
EndPointSuffix     : core.windows.net/
ConnectionString   : BlobEndpoint=https://jspshstorage.blob.core.windows.net/;QueueEndpoint=https://jspshstorage.queue.core.windows.ne
t/;TableEndpoint=https://jspshstorage.table.core.windows.net/;FileEndpoint=https://jspshstorage.file.core.windows
.net/;AccountName=jspshstorage;AccountKey=Pv6e6VMWXWgwMjs5+ZR5yiP7BACAKMvnFFjvf/ZjnK+7ZZ3N40WNByTKYyE9GaEqqY3mueQ
                     OryQvfXg8ku2arw==
ExtendedProperties : {}
```

### Get first and second Access key values from Azure account:
```powershell
PS C:\PowerShell> (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageAccountName).Value[0]
Pv6e6VMWXWgwMjs5+ZR5yiP7BACAKMvnFFjvf/ZjnK+7ZZ3N40WNByTKYyE9GaEqqY3mueQOryQvfXg8ku2arw==
PS C:\PowerShell> (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageAccountName).Value[1]
D2TG68B8FWDwu2QEWN1FdELuo20nlyjw8Jo21s91TB4a+impTm83aAistywqLDk+l6kdHGEgJKv3AwP1zTJBSQ==
```

### Generate new Access key1 and key2:
```powershell
PS C:\PowerShell> New-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageAccountName -KeyName key1
PS C:\PowerShell> New-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageAccountName -KeyName key2
```

### If you want remove storage account use the following command:
```powershell
PS C:\PowerShell> Remove-AzureRmStorageAccount -ResourceGroup $resourceGroup -AccountName $storageAccountName
```

### Create new container and set access level to Public:
```powershell
PS C:\PowerShell> $containerName = "jsblobs"
Blob End Point: https://jspshstorage.blob.core.windows.net/
Name    PublicAccess LastModified
----    ------------ ------------
jsblobs Blob         2017-11-27 13:40:36Z
```

### Create new container:
```powershell
PS C:\PowerShell> $blobName = "uploadedfolder"
PS C:\PowerShell> $localFileDirectory = "C:\PowerShell\jsfolder\"
PS C:\PowerShell> $localFile = $localFileDirectory + $blobName
PS C:\PowerShell> New-AzureStorageContainer -Name $containerName -Context $ctx -Permission blob
```

### Get history of the commands from PowerShell:
```powershell
PS C:\PowerShell> Get-History
```

### Upload all files in the current directory:
```powershell
PS C:\PowerShell> Set-AzureStorageBlobContent -File $localFile -Container $containerName -Blob $blobName -Context $ctx
```