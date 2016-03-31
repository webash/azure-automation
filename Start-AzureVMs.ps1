<#
.SYNOPSIS
	Invokes Start-AzureVM for each virtual machine matching a -like or -match pattern. Intended to be run from Azure Automation.

.PARAMETER CredentialName
	The name of the credential stored in the Azure Automation assets library.

.PARAMETER Subscription
	The name of the subscription within which to retrieve (Get-AzureVM) and shutdown (Stop-AzureVM) Azure Virtual Machines.

.PARAMETER VirtualMachinePattern
	Accepts a string with wildcard characters, to be fed to a -like statement.
	OR if also specifying isVirtualMachinePatternRegex = $true, accepts a regex pattern.

.PARAMETER isVirtualMachinePatternRegex
	Accepts $true or $false to determine whether VirtualMachinePattern takes a -like compatible, or -match (regex) compatible match string.

.PARAMETER PriorityVMsList
	Allows you to provide a list of VMs that should be booted SleepIntervalMinutes ahead of all other VMs matching the pattern.

.PARAMETER SleepIntervalMinutes
	Provide an integer that will be used as the amount of time to sleep between booting the PriorityVMsList and all other VirtualMachinePattern matching VMs.

.PARAMETER DontStartOnWeekends
	$true or $false as to whether the script should start on 'Saturday' or 'Sunday. This has only been tested for all-English environments. This is to allow for the lack of granularity in the 'daily' schedule in Azure Automation which doesn't allow for removing some days from the 'daily' list.

.EXAMPLE
	The workflow is unlikely to ever be run like this, but this gives you an idea of how to fill out the parameters when prompted by Azure Automation.
	
	Start-AzureVM.ps1 -CredentialName "Azure Automation Unattended account" -Subscription "Ashley Azure" -VirtualMachinePattern "azurevm-*" -PriorityVMsList "azurevm-dc01,azurevm-dc02" -SleepIntervalMinutes 10 -DontStartOnWeekends:$true

.EXAMPLE
	The workflow is unlikely to ever be run like this, but this gives you an idea of how to fill out the parameters when prompted by Azure Automation.
	
	Start-AzureVM.ps1 -CredentialName "Azure Automation Unattended account" -Subscription "Ashley Azure" -isVirtualMachinePatternRegex:$true -VirtualMachinePattern "^(!?azurevm-retired$)azurevm-.+$" -PriorityVMsList "azurevm-dc01,azurevm-dc02" -SleepIntervalMinutes 10 -DontStartOnWeekends:$true

.NOTES
	Author:		ashley.geek.nz
	Github:		https://github.com/webash/azure-automation/
	The credential stored in the asset library within Azure Automation will need the permission (Global Admin) within the subscription in order to start VMs.
	See Start-AzureVMs.ps1 in the same https://github.com/webash/azure-automation/ repository to _start_ VMs too.

.LINK
	https://ashley.geek.nz/2016/03/31/using-azure-automation-to-stop-and-start-azure-iaas-virtual-machines/


#>

workflow Start-AzureVMs
{
	param (
			[parameter(Mandatory=$true)]
			[string]$CredentialName,
				  
			[parameter(Mandatory=$true)] 
			[string]$Subscription,
			 
			# Help for how I end up using my Regex to _not_ match some VMs:
			# http://stackoverflow.com/a/2601318/443588
			# ^(?!azurevm-sync01$)(?!azurevm-sync03$)azurevm-.+$
			[parameter(Mandatory=$true)] 
			[string]$VirtualMachinePattern,

			[bool]$isVirtualMachinePatternRegex = $false,

			[string]$PriorityVMsList,

			[int]$SleepIntervalMinutes = 5,

			[bool]$DontStartOnWeekends = $false
    )
	
	Write-Output ( [string]::Format("----- Script Start {0} -----", (Get-Date).toString() ))
   
	Write-Output "Using credential named $CredentialName"
	$credential = Get-AutomationPSCredential -Name $CredentialName
	Add-AzureAccount -Credential $credential -ErrorAction Stop
	
	Write-Output "Shutting down VMs in $subscription"
	Select-AzureSubscription -SubscriptionName $subscription
	
	$day = (Get-Date).DayOfWeek
	if ( $DontStartOnWeekends -and ($day -eq 'Saturday' -or $day -eq 'Sunday') ) {
		Write-Output ([string]::Format("-DontStartOnWeekends switch was provided, and it is {0} - script aborting", (Get-Date).toString() ))
		Write-Output ([string]::Format("----- Script End {0} -----", (Get-Date).toString() ))
		exit
	}
	
	if (-not $PriorityVMsList.isNullOrEmpty) {
		
		$PriorityVMs = $PriorityVMsList | select-string -pattern '[^,]+' -AllMatches
	
		Write-Output ([string]::Format( "Iterating Priority VMs {0}...", $PriorityVMsList )) 
		
		foreach($VMName in $PriorityVMs){
			$VM = Get-AzureVM -ServiceName $VMName
			Write-Output ([string]::Format("{0}: {1}, {2}", $VM.Name, $VM.PowerState, $VM.Status))
			Write-Output ([string]::Format("`tStarting VM {0}...", $VM.Name))
			$operationOutput = $VM | Start-AzureVM
			Write-Output ([string]::Format("`t`t{0}", $operationOutput.OperationStatus))
			$VM = Get-AzureVM -ServiceName $VMName
			Write-Output ([string]::Format("{0}: {1}, {2}", $VM.Name, $VM.PowerState, $VM.Status))
		}
	
		Write-Output "Sleeping for $SleepIntervalMinutes..."
		for ($i = 1; $i -le $SleepIntervalMinutes; $i++) {
			#Start-Sleep -s 60
			Write-Output "`t$i min"
		}
		
		foreach($VMName in $PriorityVMs){
			$VM = Get-AzureVM -ServiceName $VMName
			Write-Output ([string]::Format("{0}: {1}, {2}", $VM.Name, $VM.PowerState, $VM.Status))
		}
	}
	
	$vmFilter = { }
	
	if ( $isVirtualMachinePatternRegex ) {
		Write-Output "Using -match mode."
		$vmFilter = { ($_.Name -match $VirtualMachinePattern -and -not($PriorityVMsList -contains $_.Name)) }
	} else {
		Write-Output "Using -like mode."
		$vmFilter = { ($_.Name -like $VirtualMachinePattern -and -not($PriorityVMsList -contains $_.Name)) }
	}
	Write-Output ([string]::Format("VirtualMachinePattern: $VirtualMachinePattern"))
	Write-Output $vmFilter
	
	Write-Output "Gathering VMs matching pattern/like..."
	$VMs = Get-AzureVM | Where-Object -FilterScript $vmFilter
	$VMs | Foreach-Object { Write-Output ([string]::Format("`t{0}: {1}, {2}", $_.Name, $_.PowerState, $_.Status)) }
	
	foreach($VM in $VMs){
		Write-Output ([string]::Format("Starting VM {0}...", $VM.Name))
		$operationOutput = $VM | Start-AzureVM
		Write-Output ([string]::Format("`t{0}", $operationOutput.OperationStatus))
	}
	
	$VMs = Get-AzureVM | Where-Object -FilterScript $vmFilter
	$VMs | Foreach-Object { Write-Output ([string]::Format("{0}: {1}, {2}", $_.Name, $_.PowerState, $_.Status)) }
	
	Write-Output ( [string]::Format("----- Script Stop {0} -----", (Get-Date).toString() ))
}