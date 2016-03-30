workflow Start-AzureVMs
{
	param (
			[parameter(Mandatory=$true)]
		    [string]$CredentialName,
				  
	        [parameter(Mandatory=$true)] 
	        [string]$Subscription,
			 
			# Help for how I end up using my Regex to _not_ match some VMs:
			# http://stackoverflow.com/a/2601318/443588
			# ^(?!hotlava-sync01$)(?!hotlava-sync03$)hotlava-.+$
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