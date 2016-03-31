<#
.SYNOPSIS
	Invokes Stop-AzureVM for each virtual machine matching a -like pattern. Intended to be run from Azure Automation.

.PARAMETER CredentialName
	The name of the credential stored in the Azure Automation assets library.

.PARAMETER Subscription
	The name of the subscription within which to retrieve (Get-AzureVM) and shutdown (Stop-AzureVM) Azure Virtual Machines.

.PARAMETER VirtualMachineLike
	Accepts a string with wildcard characters, to be fed to a -like statement.

.EXAMPLE
	The workflow is unlikely to ever be run like this, but this gives you an idea of how to fill out the parameters when prompted by Azure Automation.
	
	Shutdown-AzureVM.ps1 -CredentialName "Azure Automation Unattended account" -Subscription "Ashley Azure" -VirtualMachineLike "azurevm-*"

.NOTES
	Author:		ashley.geek.nz
	Github:		https://github.com/webash/azure-automation/
	The credential stored in the asset library within Azure Automation will need the permission (Global Admin) within the subscription in order to stop VMs.
	See Shutdown-AzureVMs.ps1 in the same https://github.com/webash/azure-automation/ repository to _stop_ VMs too.

.LINK
	https://ashley.geek.nz/2016/03/31/using-azure-automation-to-stop-and-start-azure-iaas-virtual-machines/


#>

workflow Shutdown-AzureVMs
{
	param (
		[parameter(Mandatory=$true)] 
		[string]$CredentialName,

		[parameter(Mandatory=$true)] 
		[string]$Subscription,

		[parameter(Mandatory=$true)] 
		[string]$VirtualMachineLike
	)
	
	Write-Output ( [string]::Format("----- Script Start {0} -----", (Get-Date).toString() ))
   
	Write-Output "Using credential named $CredentialName"
	$credential = Get-AutomationPSCredential -Name $CredentialName
	Add-AzureAccount -Credential $credential
	
	Write-Output "Shutting down VMs in $subscription"
	Select-AzureSubscription -SubscriptionName $subscription
	
	Write-Output "Gathering VMs with Name -like $VirtualMachineLike"
	$VMs = Get-AzureVM | Where-Object -FilterScript { $_.Name -like $VirtualMachineLike }
	$VMs | Foreach-Object { Write-Output ([string]::Format("`t{0}: {1}, {2}", $_.Name, $_.PowerState, $_.Status)) }
	
	foreach($VM in $VMs){
		Write-Output ([string]::Format("Shutting Down VM {0}...", $VM.Name))
		$operationOutput = $VM | Stop-AzureVM -force
		Write-Output ([string]::Format("`t{0}", $operationOutput.OperationStatus))
	}
	
	$VMs = Get-AzureVM | Where-Object -FilterScript { $_.Name -like $VirtualMachineLike }
	$VMs | Foreach-Object { Write-Output ([string]::Format("{0}: {1}, {2}", $_.Name, $_.PowerState, $_.Status)) }
	
	Write-Output ( [string]::Format("----- Script Stop {0} -----", (Get-Date).toString() ))
}