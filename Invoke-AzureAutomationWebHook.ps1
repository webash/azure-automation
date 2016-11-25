<#
.SYNOPSIS
	Invokes an Azure Automation Webhook that requires no parameters to be passed during run-time. Likely you want to hard-code the params into this or call it from another script.

.EXAMPLE
	Configure $uri/-Uri to be the Webhook URI, and $ExpiryDateTime/-ExpiryDateTime to be the time when the Webhook will no longer operate so that you're aware of why it fails when it inevitably does expire.
	.\Invoke-AzureAutomationWebHook.ps1 -Uri https://example.com/webhook/uri -ExpiryDateTime '1985-11-09 19:05' 

.NOTES
	Author:		ashley.geek.nz
	Version:	2016-11-24 1950
	Github:		https://github.com/webash/azure-automation/
	Reference:	https://azure.microsoft.com/en-gb/documentation/articles/automation-webhooks/

.LINK
	https://github.com/webash/azure-automation/

#>
param(
	[ValidateNotNullOrEmpty()][string]$uri = '',
	[ValidateNotNullOrEmpty()][string]$ExpiryDateTime = "1970-01-01 00:01"
);

function AreYouSure {
	# Keep window open on failure from: http://blog.danskingdom.com/keep-powershell-console-window-open-after-script-finishes-running/
	if ($Host.Name -eq "ConsoleHost")
	{
		Write-Host "Press any key to continue..."
		$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null;
	}
}

try {
	$ExpiryDateTimeCast = [datetime]$ExpiryDateTime;
} catch {
	Write-Error "ExpiryDateTime was not a parsable DateTime string. Including this parameter is a courtesy to the end-user so they're aware of when their WebHook will expire.";
	AreYouSure;
	exit;
}

if ( $ExpiryDateTimeCast -lt (Get-Date) ) {
	Write-Error "It is likely this WebHook invocation will fail, as the expiry date for the webhook was $($ExpiryDateTimeCast -f "yyyyMMdd HHmm"). You will need to request/create a new one.";
} elseif ( $ExpiryDateTimeCast -lt (Get-Date).AddDays(30) ) {
	Write-Warning "There is less than 30 days left of this WebHook's validity. You may wish to request another."
	AreYouSure;
}

$headers = @{"From"="$(whoami)";"Date"="$(Get-Date)"};

Write-Host "Invoking Webhook as $(whoami)..." -ForegroundColor Cyan -NoNewLine;

$response = Invoke-WebRequest -Method Post -Uri $uri -Headers $headers -Body $null;
$jobid = ConvertFrom-Json $response.Content;

if ( $response.StatusCode -eq 202 ) {
	Write-Host "Success" -ForegroundColor Green;
	Write-Host "`tResponse JSON: $($response.Content)";
} else {
	Write-Host "Failed" -ForegroundColor Red;
	$response | fl *;

	AreYouSure;
}