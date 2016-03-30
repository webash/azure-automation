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