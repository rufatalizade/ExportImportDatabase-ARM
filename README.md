## This article is about creating two Azure SQL Server/DB then export/import from first one to second.

#### This readme include explanation "Deploy-AzureResourceGroup.ps1" file (starting from 120 line). Before 120 line, script includes Microsoft official ARM deploy.


### For working with AzureSQL we have to install SqlServer module. 
```powershell 
Install-module -Name SqlServer -Scope CurrentUser
```

### This command get 
```powershell
$lastRgDeployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName  $ResourceGroupName | Sort-Object Timestamp -Descending | Select-Object -First 1 
```
