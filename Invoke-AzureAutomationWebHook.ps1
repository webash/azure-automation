<#
.SYNOPSIS
	Invokes an Azure Automation Webhook that requires no parameters to be passed during run-time.

.NOTES
	Author:		ashley.geek.nz
	Github:		https://github.com/webash/azure-automation/
	Reference:	https://azure.microsoft.com/en-gb/documentation/articles/automation-webhooks/

.LINK
	https://github.com/webash/azure-automation/

#>

$uri = "";
$headers = @{"From"="$(whoami)";"Date"="$(get-date)"};

Write-Host "Invoking Webhook as $(whoami)..." -ForegroundColor Cyan -NoNewLine;

$response = Invoke-WebRequest -Method Post -Uri $uri -Headers $headers -Body $null;
$jobid = ConvertFrom-Json $response.Content;

if ( $response.StatusCode -eq 202 ) {
	Write-Host "Success" -ForegroundColor Green;
	Write-Host "`tJob Id: $jobId";
} else {
	Write-Host "Failed" -ForegroundColor Red;
	$response | fl *
}