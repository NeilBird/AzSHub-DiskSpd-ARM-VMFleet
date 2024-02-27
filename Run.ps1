<#
.NOTES
    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 
    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
    implied warranties including, without limitation, any implied warranties of merchantability
    or of fitness for a particular purpose. The entire risk arising out of the use or performance
    of the sample and documentation remains with you. In no event shall Microsoft, its authors,
    or anyone else involved in the creation, production, or delivery of the script be liable for 
    any damages whatsoever (including, without limitation, damages for loss of business profits, 
    business interruption, loss of business information, or other pecuniary loss) arising out of 
    the use of or inability to use the sample or documentation, even if Microsoft has been advised 
    of the possibility of such damages, rising out of the use of or inability to use the sample script, 
    even if Microsoft has been advised of the possibility of such damages. 
#>

# Requires Az modules to be installed for Azure Stack Hub:
# https://learn.microsoft.com/en-us/azure-stack/operator/powershell-install-az-module

# Credentials for the VMs
$cred = Get-Credential -UserName "admin" -Message "Admin credentials for the VMs"

# Set the location of the script directory, Default to script execution folder
if([string]::IsNullOrWhiteSpace($script:MyInvocation.MyCommand.Path)){
    $ScriptDir = "."
} else {
    $ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
}
Set-Location -Path $ScriptDir

# Initialise the DSC configuration, this installs the required DCS resource modules locally.
.\_pre-req_Initialise_DSC.ps1

# Requires authenticated session to Azure Stack Hub:
# ACTION: Update the script below, before executing it, using the required parameters for your Region, Fqdn and Tenant name.
.\_pre-req_Example_Connect.ps1

# Use Grid view to select the User Subscription to deploy the ARM VM Fleet to..
[string]$GridViewTile = "Select the Subscription/Tenant ID to deploy the ARM VM Fleet to..."
try{
    $AzContext = (Get-AzSubscription -ErrorAction Stop | Out-GridView `
    -Title $GridViewTile `
    -PassThru)
    Try {
        # Set the context to the selected subscription
         Set-AzContext -TenantId $AzContext.TenantID -SubscriptionId $AzContext.Id -ErrorAction Stop -WarningAction Stop
    } Catch [System.Management.Automation.PSInvalidOperationException] {
        # Catch any exceptions and display the error message
        Write-Error "Exception: $($error[0].Exception)"
        break
    }
} catch {
    # Catch any exceptions and display the error message
    Write-Host "Error: $_"
    Write-Host "Please ensure you are authenticated to the target Azure Stack Hub using Login-AzAccount"
    break
}

# DiskSpd information
# https://github.com/microsoft/diskspd/blob/master/README.md
# https://github.com/Microsoft/diskspd/wiki
# https://github.com/Microsoft/diskspd/wiki/Command-line-and-parameters
# Example DiskSpd params, defaults to 64K block size, 100% random write / reads, 15 threads, 20GB test file, 1 hour duration, 64 outstanding I/Os, and XML output file
# Write test: -c20G -w100 -F15 -r -o64 -d3600 -Sh -Rxml
# Read test: -c20G -F15 -r -o64 -d3600 -Sh -Rxml
# Large area sequential concurrent writes: -c20G -w100 -F15 -T1b -s8b -o64 -d3600 -Sh -Rxml
# Large area sequential concurrent reads: -c20G -F15 -T1b -s8b -o64 -d3600 -Sh -Rxml
# -c100G -t32 -o64 -d4800 -w50 -Sh -Rxml

# Standard_F16s has 16 x vCPUs and can have up to 64 x data disks.
# Max time for DSC extension is 90 minutes, allowing 10 minutes spare, results in 80 minutes, which is 4800 seconds.
# Check Qutoas on Admin Portal for max resoruces allowed, cores, VMs, managed disks...etc
# 50 x 10GB data disks = 1000GB = 500GB per VM
# 30 x 10GB data disks = 300GB = 150GB per VM

# Check Hub Compute Quotas before running the script, needs vCPU, VMs, Managed Disks resources
# VM deployment logs default to "C:\ARM-VMFleet-Logs\"

# start ARM-VMFleet
.\ARM_VMFleet.ps1 -initialise -cred $cred -totalVmCount 10 -pauseBetweenVmCreateInSeconds 5 -location '<location>' -vmsize 'Standard_F16s' `
    -storageUrlDomain 'blob.<region>.<fqdn>' -testParams '-c100G -t32 -o64 -d4800 -w50 -Sh -Rxml' -dataDiskSizeGb 10 `
     -resourceGroupNamePrefix 'VMfleet-' -password $cred.Password -dontDeleteResourceGroupOnComplete -vmNamePrefix 'iotest' `
     -dataDiskCount 20 -resultsStorageAccountName 'testharness'



