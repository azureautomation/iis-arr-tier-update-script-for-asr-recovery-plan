IIS ARR tier update script for ASR Recovery Plan
================================================

            

 

After Failover of data and web tier in IIS workload, this runbook runs powershell script which updates Site Bindings on IIS server and Web farms on ARR. This runbook requires  Push-AzureVMCommand runbook to be imported from
 gallery in azure automation account. Runs this PowerShell script to update Site Bindings on IIS server and Web farms on ARR.

 



Download IIS-Update-WebFarm.ps1 script from [here](https://aka.ms/asr-iis-update-webfarm-script-classic).



 



**Online peer support**
 For online peer support, join
[The Official Scripting Guys Forum!](https://aka.ms/asr-public-forum) To provide feedback or report bugs in sample scripts, please start a new discussion on the Discussions tab for this script.


 


        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
