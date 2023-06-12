<#
.SYNOPSIS
Renames the existing Application Group Desktop to a friendly name.

.DESCRIPTION
This script will connect to Azure and rename the SessionHost desktop for the required Application Group to the required name.

This script requires a Service Principal for connection to Azure.
#>

param(
    [Parameter(mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(mandatory = $true)]
    [string]$ApplicationGroupName,
    [Parameter(mandatory = $true)]
    [string]$DesktopName,
    [Parameter(mandatory = $true)]
    [string]$AzTenantID,
    [Parameter(mandatory = $true)]
    [string]$AppID,
    [Parameter(mandatory = $true)]
    [string]$AppSecret
)

$ScriptPath = [system.IO.path]::GetDirectoryName($PSCommandPath)
. (Join-Path $ScriptPath "Functions.ps1")

#Install Pre-Req modules
Install-packageProvider -Name NuGet -MinimumVErsion 2.8.5.201 -force
Install-Module -Name Az.DesktopVirtualization -AllowClobber -Force
Install-Module -Name Az.Accounts -AllowClobber -Force
Import-Module -Name Az.DesktopVirtualization

Write-Log -Message "Starting Script. Renaming Desktop name."
#Create credential object to connect to Azure
$Creds= New-Object System.Management.Automation.PSCredential($AppID, (ConvertTo-SecureString $AppSecret -AsPlainText -Force))

Write-Log -Message "Connecting to Azure."
#Connect to Azure
Connect-AzAccount -ServicePrincipal -Credential $Creds -TenantID $AzTenantID

#Update the Application Group Desktop FriendlyName
Write-Log -Message "Attempting to rename Desktop name."
try {
    Update-AzWVDDesktop -ResourceGroupName $ResourceGroup -ApplicationGroupName $ApplicationGroupName -Name $DesktopName -FriendlyName $DesktopName -ErrorAction Stop
    Write-Log -Message "Successfully renamed Desktop."

} catch {
    Write-Log -Error "Failed to rename Desktop"
    Write-Log -Error "Error Details: $_"
}

