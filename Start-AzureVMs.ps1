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
	Allows you to provide a list of VM ServiceNames (!important!) that should be booted SleepIntervalMinutes ahead of all other VMs matching the pattern.

.PARAMETER SleepIntervalMinutes
	Provide an integer that will be used as the amount of time to sleep between booting the PriorityVMsList and all other VirtualMachinePattern matching VMs.

.PARAMETER DontStartOnWeekends
	$true or $false as to whether the script should start on 'Saturday' or 'Sunday. This has only been tested for all-English environments. This is to allow for the lack of granularity in the 'daily' schedule in Azure Automation which doesn't allow for removing some days from the 'daily' list.

.PARAMETER AzureClassic
	If $true, the script will use the classic (non-Resource Manager/RM/ARM) cmdlets for Azure Classic VMs.

.EXAMPLE
	The workflow is unlikely to ever be run like this, but this gives you an idea of how to fill out the parameters when prompted by Azure Automation.
	
	Start-AzureVM.ps1 -CredentialName "Azure Automation Unattended account" -Subscription "Ashley Azure" -VirtualMachinePattern "azurevm-*" -PriorityVMsList "azurevm-dc01,azurevm-dc02" -SleepIntervalMinutes 10 -DontStartOnWeekends:$true

.EXAMPLE
	The workflow is unlikely to ever be run like this, but this gives you an idea of how to fill out the parameters when prompted by Azure Automation.
	
	Start-AzureVM.ps1 -CredentialName "Azure Automation Unattended account" -Subscription "Ashley Azure" -isVirtualMachinePatternRegex:$true -VirtualMachinePattern "^(!?azurevm-retired$)azurevm-.+$" -PriorityVMsList "azurevm-dc01,azurevm-dc02" -SleepIntervalMinutes 10 -DontStartOnWeekends:$true

.NOTES
	Author:		ashley.geek.nz
	Version:	2016-04-11 03:08 BST
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

			[bool]$DontStartOnWeekends = $false,
			
			[parameter(Mandatory=$false)]
			[bool]$AzureClassic = $false
    )
	
<#
	function Filter-VMs {
		param (
			$VMs
		)
		
		if ( $Using:isVirtualMachinePatternRegex ) {
			return $VMs | Where-Object -filterScript { ($_.Name -match $Using:VirtualMachinePattern -and -not ($Using:PriorityVMsList -contains $_.Name)) }
		} else {
			return $VMs | Where-Object -filterScript { ($_.Name -like $Using:VirtualMachinePattern -and -not ($Using:PriorityVMsList -contains $_.Name)) }
		}
	}
#>
	
	Write-Output ( [string]::Format("----- Script Start {0} -----", (Get-Date).toString() ))
	
	if ( $AzureClassic ) {
		Write-Output "Azure VM Classic cmdlets will be used for this session because -AzureClassic is true"
	}
   
	Write-Output "Using credential named $CredentialName"
	$credential = Get-AutomationPSCredential -Name $CredentialName
	if ( -not $AzureClassic ) {
		Add-AzureRmAccount -Credential $credential -ErrorAction Stop
	} else {
		Add-AzureAccount -Credential $credential -ErrorAction Stop
	}
	
	Write-Output "Using $subscription subscription"
	if ( -not $AzureClassic ) {
		Select-AzureRmSubscription -SubscriptionName $subscription
	} else {
		Select-AzureSubscription -SubscriptionName $subscription
	}
	
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
			if ( -not $AzureClassic ) {
				$VM = Get-AzureRmVM | Where-Object -filterScript { $_.name -eq $VMName }
				$VM | Get-AzureRmVm -Status | Get-AzureRmVm -Status | Foreach-Object { Write-Output ([string]::Format("`t{0}\{1}: {2}, {3}", $_.ResourceGroupName, $_.Name, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).code, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).displayStatus)) }
			} else {
				$VM = Get-AzureVM | Where-Object -filterScript { $_.name -eq $VMName }
				Write-Output ([string]::Format("`tClassic\{0}: {1}, {2}", $VM.Name, $VM.PowerState, $VM.Status))
			}
			
			if ( $VM -ne $null ) {
				Write-Output ([string]::Format("`tStarting VM {0}...", $VM.Name))
				if ( -not $AzureClassic ) {
					$operationOutput = $VM | Start-AzureRmVM
					if ( $operationOutput.IsSuccessStatusCode ) {
						Write-Output ([string]::Format("`t{0}", $operationOutput.ReasonPhrase))
					} else {
						Write-Error ([string]::Format("`tError: {0}", $operationOutput.ReasonPhrase))
					}
				} else {
					$operationOutput = $VM | Start-AzureVM
					Write-Output ([string]::Format("`t`t{0}", $operationOutput.OperationStatus))
				}

				if ( -not $AzureClassic ) {
					$VM = Get-AzureRmVM | Where-Object -filterScript { $_.name -eq $VMName }
					$VM | Get-AzureRmVm -Status | Get-AzureRmVm -Status | Foreach-Object { Write-Output ([string]::Format("`t{0}\{1}: {2}, {3}", $_.ResourceGroupName, $_.Name, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).code, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).displayStatus)) }
				} else {
					$VM = Get-AzureVM | Where-Object -filterScript { $_.name -eq $VMName }
					Write-Output ([string]::Format("`tClassic\{0}: {1}, {2}", $VM.Name, $VM.PowerState, $VM.Status))
				}
			} else {
				Write-Output "`t`t$VMName doesn't exist"
			}
		}
	
		Write-Output "Sleeping for $SleepIntervalMinutes min to give Priority VMs chance to start-up..."
		for ($i = 1; $i -le $SleepIntervalMinutes; $i++) {
			Start-Sleep -Seconds 60
			Write-Output "`t$i min"
		}

		Write-Output "Confirming new status of PriorityVMsList..."		
		foreach ($VMName in $PriorityVMs) {
			if ( -not $AzureClassic ) {
				$VM = Get-AzureRmVM | Where-Object -filterScript { $_.name -eq $VMName }
				$VM | Get-AzureRmVm -Status | Get-AzureRmVm -Status | Foreach-Object { Write-Output ([string]::Format("`t{0}\{1}: {2}, {3}", $_.ResourceGroupName, $_.Name, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).code, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).displayStatus)) }
			} else {
				$VM = Get-AzureVM | Where-Object -filterScript { $_.name -eq $VMName }
				Write-Output ([string]::Format("`tClassic\{0}: {1}, {2}", $VM.Name, $VM.PowerState, $VM.Status))
			}
		}
	}
	
	<#$vmFilter = { }
	
	if ( $isVirtualMachinePatternRegex ) {
		Write-Output "Using -match mode."
		$vmFilter = { ($_.Name -match $VirtualMachinePattern -and -not ($PriorityVMsList -contains $_.Name)) }
	} else {
		Write-Output "Using -like mode."
		$vmFilter = { ($_.Name -like $VirtualMachinePattern -and -not ($PriorityVMsList -contains $_.Name)) }
	}#>
	
	$vmFilter = { (($isVirtualMachinePatternRegex -and $_.Name -match $VirtualMachinePattern) -or $_.Name -like $VirtualMachinePattern) -and -not ($PriorityVMsList -contains $_.Name) }
	
	Write-Output ([string]::Format("VirtualMachinePattern: {0}", $VirtualMachinePattern))
	Write-Output "`t$vmFilter"
	
	Write-Output "Gathering VMs matching pattern/like..."
	if ( -not $AzureClassic ) {
		$VMs = Get-AzureRmVM | Where-Object -filterScript { (($isVirtualMachinePatternRegex -and $_.Name -match $VirtualMachinePattern) -or $_.Name -like $VirtualMachinePattern) -and -not ($PriorityVMsList -contains $_.Name) }
		$VMs | Get-AzureRmVm -Status | Get-AzureRmVm -Status | Foreach-Object { Write-Output ([string]::Format("`t{0}\{1}: {2}, {3}", $_.ResourceGroupName, $_.Name, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).code, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).displayStatus)) }
	} else {
		$VMs = Get-AzureVM | Where-Object -filterScript { (($isVirtualMachinePatternRegex -and $_.Name -match $VirtualMachinePattern) -or $_.Name -like $VirtualMachinePattern) -and -not ($PriorityVMsList -contains $_.Name) }
		$VMs | Foreach-Object { Write-Output ([string]::Format("`tClassic\{0}: {1}, {2}", $_.Name, $_.PowerState, $_.Status)) }
	}
	
	Write-Output "Starting pattern-matched VMs in parallel..."
	ForEach -Parallel ($VM in $VMs){
		Write-Output ([string]::Format("`tStarting VM {0}...", $VM.Name))
		if ( -not $AzureClassic ) {
			$parallelOperationOutput = $VM | Start-AzureRmVM
			if ( $parallelOperationOutput.IsSuccessStatusCode ) {
				Write-Output ([string]::Format("`t{0}\{1}: {2}", $VM.Name, $parallelOperationOutput.ReasonPhrase))
			} else {
				Write-Error ([string]::Format("`t{0}\{1} error: {2}", $_.ResourceGroupName, $VM.Name, $parallelOperationOutput.ReasonPhrase))
			}
		} else {
			$parallelOperationOutput = $VM | Start-AzureVM
			Write-Output ([string]::Format("`tClassic\{0}: {1}", $VM.Name, $parallelOperationOutput.OperationStatus))
		}
	}

	Write-Output "Confirming new status of VMs with Name -like/-match $VirtualMachineLike"
	if ( -not $AzureClassic ) {
		Get-AzureRmVM | Get-AzureRmVm -Status | Where-Object -FilterScript { (($isVirtualMachinePatternRegex -and $_.Name -match $VirtualMachinePattern) -or $_.Name -like $VirtualMachinePattern) -and -not ($PriorityVMsList -contains $_.Name) } |`
			Foreach-Object { Write-Output ([string]::Format("`t{0}\{1}: {2}, {3}", $_.ResourceGroupName, $_.Name, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).code, (($_.StatusesText | convertfrom-json) | Where-Object -FilterScript { $_.code -like "PowerState*" }).displayStatus)) }
	} else {
		Get-AzureVM | Where-Object -FilterScript { (($isVirtualMachinePatternRegex -and $_.Name -match $VirtualMachinePattern) -or $_.Name -like $VirtualMachinePattern) -and -not ($PriorityVMsList -contains $_.Name) } | `
			Foreach-Object { Write-Output ([string]::Format("`tClassic\{0}: {1}, {2}", $_.Name, $_.PowerState, $_.Status)) }
	}
	
	Write-Output ( [string]::Format("----- Script Stop {0} -----", (Get-Date).toString() ))
}