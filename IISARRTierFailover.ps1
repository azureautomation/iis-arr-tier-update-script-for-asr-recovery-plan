<#
  
.SYNOPSIS 
    Runbook to run a custom script inside an Azure Virtual Machine 
    This script needs to be used along with recovery plans in Azure Site Recovery

.DESCRIPTION
    After Failover of data and web tier in IIS workload, this runbook runs powershell script which updates Site Bindings on IIS server 
    and Web farms on ARR. This runbook requires  Push-AzureVMCommand runbook to be imported from gallery in azure automation account.	       
    Runs this PowerShell script to update Site Bindings on IIS server and Web farms on ARR.

    Download IIS-Update-WebFarm.ps1 script from TechNet gallary and store it locally. Use the local path in "ScriptLocalFilePath" variable.
    Now upload the script to your Azure storage account using following command. Command is given the example value. 
    Replace following items as per your account name and key and container name: 
    "ScriptScriptStorageAccountName", ScriptStorageAccountKey", "ContainerName"
        
    $context = New-AzureStorageContext -ScriptStorageAccountName "ScriptScriptStorageAccountName" -StorageAccountKey "ScriptStorageAccountKey"
    Set-AzureStorageBlobContent -Blob "IIS-Update-WebFarm.ps1" -Container "ContainerName" -File "ScriptLocalFilePath" -context $context
    
    Specify $AutomationAccountName with the required value. Runbook needs it to create an asset.

.ASSETS
    Following Assets you need to create before running the runbook 
    'ScriptScriptStorageAccountName': Name of the storage account where the script is stored
    'ScriptStorageAccountKey': Key for the storage account where the script is stored
    'AzureSubscriptionName': Azure Subscription Name to use
    'ContainerName': Container in which script is uploaded
    'IIS-Update-WebFarm': Name of script
    
    in the azure automation account You can choose to encrtypt these assets
    
    

.PARAMETER RecoveryPlanContext
    RecoveryPlanContext is the only parameter you need to define.
    This parameter gets the failover context from the recovery plan. 

.NOTE
    The script is for Azure classic portal only. 

    Author: sakulkar@microsoft.com
#>

workflow IISARRTierFailover
{
    param
    (
        [Object]$RecoveryPlanContext
    )    
    try
    {
        $AzureOrgIdCredential = Get-AutomationPSCredential -Name 'YourAzureOrgIdCredential'
        $AzureAccount = Add-AzureAccount -Credential $AzureOrgIdCredential
        $AzureSubscriptionName = Get-AutomationVariable -Name 'yourAzureSubscriptionName'
        Select-AzureSubscription -SubscriptionName $AzureSubscriptionName

        $vmMap = $RecoveryPlanContext.VmMap.PsObject.Properties
        $RecoveryPlanName = $RecoveryPlanContext.RecoveryPlanName

        #Provide the storage account name and the storage account key information
        $ScriptStorageAccountName = Get-AutomationVariable -Name 'YourScriptScriptStorageAccountName'
        $ScriptStorageAccountKey  =  Get-AutomationVariable -Name 'YourScriptScriptStorageAccountKey'

        #Script Details
        $ContainerName = Get-AutomationVariable -Name 'YourContainerName'
        $ScriptName = "IIS-Update-WebFarm.ps1"

        #Provide Automation Account Details
        $AutomationAccountName = "YourAutomationAccountName"

        foreach($VMProperty in $vmMap)
        {
            $VM = $VMProperty.Value
            $ARRVMName = $VMProperty.Value.RoleName
            $ServiceName = $VMProperty.Value.CloudServiceName
        }

        if(($ARRVMName -ne $null) -or ($ARRVMName -ne ""))
        {
            $AssetName = "$Using:RecoveryPlanName-IPMapping"
            $IPAddressMapping = Get-AzureAutomationVariable -Name $AssetName -AutomationAccountName $AutomationAccountName -ErrorAction Stop
            write-output $IPAddressMapping.Value

            InLineScript
            {
                $context = New-AzureStorageContext -ScriptStorageAccountName $Using:ScriptStorageAccountName -ScriptStorageAccountKey $Using:ScriptStorageAccountKey
                $sasuri = New-AzureStorageBlobSASToken -Container $Using:ContainerName -Blob $Using:ScriptName -Permission r -FullUri -Context $context

                $VM = Get-AzureVM -Name $ARRVMName -ServiceName $ServiceName

                Write-Output "UnInstalling custom script extension"
                Set-AzureVMCustomScriptExtension -Uninstall -ReferenceName CustomScriptExtension -VM $VM |Update-AzureVM 
                Write-Output "Installing custom script extension"
                Set-AzureVMExtension -ExtensionName CustomScriptExtension -VM $VM -Publisher Microsoft.Compute -Version 1.*| Update-AzureVM

                $IPMapping=$Using:IPAddressMapping.Value
                $IPMapping=$IPMapping -ireplace "\\n",""
                $IPMappingTable=[System.management.automation.psserializer]::deserialize($IPMapping)

                foreach ($Mapping in $IPMappingTable.GetEnumerator())
                {
                    $Pair = "$($Mapping.Name),$($Mapping.Value)"

                    Write-output "Updating Server Farm with (Old IP Address),(New IP Address) : $Pair"
                    Set-AzureVMCustomScriptExtension -VM $VM -FileUri $sasuri -Run $Using:ScriptName -Argument $Pair| Update-AzureVM
                    Write-output "Updated Server Farm"
                }
            }
            Remove-AzureAutomationVariable -Name $AssetName -AutomationAccountName $AutomationAccountName
        }
    }
    catch
    {
        $ErrorMessage = $ErrorMessage+$_.Exception.Message	
        Write-output $ErrorMessage
    }
}
