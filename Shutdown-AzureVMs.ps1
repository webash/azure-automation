<#
.SYNOPSIS
	Invokes Stop-AzureVM for each virtual machine matching a -like pattern. Intended to be run from Azure Automation.

.PARAMETER CredentialName
	The name of the credential stored in the Azure Automation assets library.

.PARAMETER Subscription
	The name of the subscription within which to retrieve (Get-AzureVM) and shutdown (Stop-AzureVM) Azure Virtual Machines.

.PARAMETER VirtualMachineLike
	Accepts a string with wildcard characters, to be fed to a -like statement.

.PARAMETER AzureClassic
	If $true, the script will use the classic (non-Resource Manager/RM/ARM) cmdlets for Azure Classic VMs.

.EXAMPLE
	The workflow is unlikely to ever be run like this, but this gives you an idea of how to fill out the parameters when prompted by Azure Automation.
	
	Shutdown-AzureVM.ps1 -CredentialName "Azure Automation Unattended account" -Subscription "Ashley Azure" -VirtualMachineLike "azurevm-*"

.NOTES
	Author:		ashley.geek.nz
	Version:	2016-04-11 00:00 BST
	Github:		https://github.com/webash/azure-automation/
	The credential stored in the asset library within Azure Automation will need the permission (Virtual Machine contributor or higher) within the subscription in order to stop VMs.
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
		[string]$VirtualMachineLike,
		
		[parameter(Mandatory=$false)]
		[bool]$AzureClassic = $false
	)
	
	Write-Output ( [string]::Format("----- Script Start {0} -----", (Get-Date).toString() ))
	
	if ( $AzureClassic ) {
		Write-Output "Azure VM Classic cmdlets will be used for this session because -AzureClassic is true"
	}
   
	Write-Output "Using credential named $CredentialName"
	$credential = Get-AutomationPSCredential -Name $CredentialName
	if ( -not $AzureClassic ) {
		Add-AzureRmAccount -Credential $credential
	} else {
		Add-AzureAccount -Credential $credential
	}
	
	Write-Output "Shutting down VMs in $subscription"
	if ( -not $AzureClassic ) {
		Select-AzureRmSubscription -SubscriptionName $subscription
	} else {
		Select-AzureSubscription -SubscriptionName $subscription
	}
	
	Write-Output "Gathering VMs with Name -like $VirtualMachineLike"
	if ( -not $AzureClassic ) {
		$RawVMs = Get-AzureRmVM
	} else {
		$RawVMs = Get-AzureVM
	}
	$VMs = $RawVMs | Where-Object -FilterScript { $_.Name -like $VirtualMachineLike }
	
	if ( -not $AzureClassic ) {
		$VMs | Get-AzureRmVm -Status | Get-AzureRmVm -Status | Foreach-Object { Write-Output ([string]::Format("`t{0}\{1}: {2}, {3}", $_.ResourceGroupName, $_.Name, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).code, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).displayStatus)) }
	} else {
		$VMs | Foreach-Object { Write-Output ([string]::Format("`tClassic\{0}: {1}, {2}", $_.Name, $_.PowerState, $_.Status)) }
	}

	Write-Output "Stopping pattern-matched VMs in parallel..."
	ForEach -Parallel ($VM in $VMs){
		Write-Output ([string]::Format("Shutting Down VM {0}...", $VM.Name))
		if ( -not $AzureClassic ) {
			$operationOutput = $VM | Stop-AzureRmVM -force
			if ( $operationOutput.IsSuccessStatusCode ) {
				Write-Output ([string]::Format("`t{0}: {1}", $VM.Name, $operationOutput.ReasonPhrase))
			} else {
				Write-Error ([string]::Format("`t{0} error: {1}", $VM.Name, $operationOutput.ReasonPhrase))
			}
		} else {
			$operationOutput = $VM | Stop-AzureVM -force
			Write-Output ([string]::Format("`t{0}: {1}", $VM.Name, $operationOutput.OperationStatus))
		}
	}

	Write-Output "Confirming new status of VMs with Name -like $VirtualMachineLike"
	if ( -not $AzureClassic ) {
		$RawVMs = Get-AzureRmVM
	} else {
		$RawVMs = Get-AzureVM
	}
	$VMs = $RawVMs | Where-Object -FilterScript { $_.Name -like $VirtualMachineLike }
	
	if ( -not $AzureClassic ) {
		$VMs | Get-AzureRmVm -Status | Foreach-Object { Write-Output ([string]::Format("`t{0}\{1}: {2}, {3}", $_.ResourceGroupName, $_.Name, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).code, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).displayStatus)) }
	} else {
		$VMs | Foreach-Object { Write-Output ([string]::Format("`tClassic\{0}: {1}, {2}", $_.Name, $_.PowerState, $_.Status)) }
	}
	
	Write-Output ( [string]::Format("----- Script Stop {0} -----", (Get-Date).toString() ))
}