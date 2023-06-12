<#

.SYNOPSIS
Creating Hostpool and add sessionhost servers to existing/new Hostpool.

.DESCRIPTION
This script add sessionhost servers to existing/new Hostpool
The supported Operating Systems Windows Server 2016.

.ROLE
Readers

#>
param(
    [Parameter(Mandatory = $true)]
    [string]$AzTenantID,
    [Parameter(mandatory = $true)]
    [string]$HostPoolName,
    [Parameter(mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(mandatory = $true)]
    [string]$AppID,
    [Parameter(mandatory = $true)]
    [string]$AppSecret
)

$ScriptPath = [system.io.path]::GetDirectoryName($PSCommandPath)

# Dot sourcing Functions.ps1 file
. (Join-Path $ScriptPath "Functions.ps1")

# Setting ErrorActionPreference to stop script execution when error occurs
$ErrorActionPreference = "Stop"

Write-Log -Message "Identifying if this VM is Build >= 1809"
$rdshIs1809OrLaterBool = Is1809OrLater

Write-Log -Message "Creating a folder inside rdsh vm for extracting deployagent zip file"
$DeployAgentLocation = "C:\DeployAgent"
ExtractDeploymentAgentZipFile -ScriptPath $ScriptPath -DeployAgentLocation $DeployAgentLocation

Write-Log -Message "Changing current folder to Deployagent folder: $DeployAgentLocation"
Set-Location "$DeployAgentLocation"

# Checking if RDInfragent is registered or not in rdsh vm
$CheckRegistry = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent" -ErrorAction SilentlyContinue

Write-Log -Message "Checking whether VM was Registered with RDInfraAgent"

if ($CheckRegistry)
{
    Write-Log -Message "VM was already registered with RDInfraAgent, script execution was stopped"
}
else
{
    Write-Log -Message "VM not registered with RDInfraAgent, script execution will continue"


    # Get Hostpool Registration Token
    Write-Log -Message "Checking for existing registration token"
    #Install Pre-Req modules
    Install-packageProvider -Name NuGet -MinimumVErsion 2.8.5.201 -force
    Install-Module -Name Az.DesktopVirtualization -AllowClobber -Force
    Install-Module -Name Az.Accounts -AllowClobber -Force
    Install-Module -Name Az.Resources -AllowClobber -Force
    Import-Module -Name Az.DesktopVirtualization

    #Create credential object to connect to Azure
    $Creds= New-Object System.Management.Automation.PSCredential($AppID, (ConvertTo-SecureString $AppSecret -AsPlainText -Force))

    Connect-AzAccount -ServicePrincipal -Credential $Creds -TenantID $AzTenantID

    $Registered = Get-AzWvdRegistrationInfo -ResourceGroupName "$resourceGroupName" -HostPoolName $HostPoolName
    if (-not(-Not $Registered.Token)){ 
        $registrationTokenValidFor = (NEW-TIMESPAN -Start (get-date) -End $Registered.ExpirationTime | select-object Days,Hours,Minutes,Seconds)
        Write-Log -Message "Registration Token found."
        Write-Log -Message $registrationTokenValidFor
    }


    if ((-Not $Registered.Token) -or ($Registered.ExpirationTime -le (get-date)))
    {
        Write-Log -Message "Valid Registration Token not found. Generating new token with 8 hours expiration"
        $Registered = New-AzWvdRegistrationInfo -ResourceGroupName $resourceGroupName -HostPoolName $HostPoolName -ExpirationTime (Get-Date).AddHours(8) -ErrorAction SilentlyContinue
    }

    $RegistrationInfoToken = $Registered.Token

    # Executing DeployAgent psl file in rdsh vm and add to hostpool
    Write-Log "AgentInstaller is $DeployAgentLocation\RDAgentBootLoaderInstall, InfraInstaller is $DeployAgentLocation\RDInfraAgentInstall, SxS is $DeployAgentLocation\RDInfraSxSStackInstall"
    $DAgentInstall = .\DeployAgent.ps1 -AgentBootServiceInstallerFolder "$DeployAgentLocation\RDAgentBootLoaderInstall" `
                                       -AgentInstallerFolder "$DeployAgentLocation\RDInfraAgentInstall" `
                                       -SxSStackInstallerFolder "$DeployAgentLocation\RDInfraSxSStackInstall" `
                                       -EnableSxSStackScriptFolder "$DeployAgentLocation\EnableSxSStackScript" `
                                       -RegistrationToken $RegistrationInfoToken `
                                       -StartAgent $true `
                                       -rdshIs1809OrLater $rdshIs1809OrLaterBool
    
    Write-Log -Message "DeployAgent Script was successfully executed and RDAgentBootLoader,RDAgent,StackSxS installed inside VM for existing hostpool: $HostPoolName`n$DAgentInstall"
}