<#
.SYNOPSIS
Adds the required User Assignment to the Application Group.

.DESCRIPTION
This script will connect to Azure and assign the main WVD access group to have access to the WVD environment.

This script requires a Service Principal for connection to Azure.
#>
param
(
    [Parameter(mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(mandatory = $true)]
    [string]$ApplicationGroupName,
    [Parameter(Mandatory = $true)]
    [string]$AzTenantID,
    [Parameter(Mandatory = $true)]
    [string]$HostPoolName,
    [Parameter(mandatory = $true)]
    [string]$AppID,
    [Parameter(mandatory = $true)]
    [string]$AppSecret,
    [Parameter(mandatory = $false)]
    [string]$DefaultUsers
)

$ScriptPath = [system.IO.path]::GetDirectoryName($PSCommandPath)
. (Join-Path $ScriptPath "Functions.ps1")

$ErrorActionPreference = "Stop"

Write-Log -Message "Starting Script. Adding Application Group Users"

#Install Pre-Req modules
Install-packageProvider -Name NuGet -MinimumVErsion 2.8.5.201 -force
Install-Module -Name Az.DesktopVirtualization -AllowClobber -Force
Install-Module -Name Az.Accounts -AllowClobber -Force
Install-Module -Name Az.Resources -AllowClobber -Force
Import-Module -Name Az.DesktopVirtualization

#Create credential object to connect to Azure
$Creds= New-Object System.Management.Automation.PSCredential($AppID, (ConvertTo-SecureString $AppSecret -AsPlainText -Force))

Connect-AzAccount -ServicePrincipal -Credential $Creds -TenantID $AzTenantID

Write-Log -Message "Checking that Host Pool does not already exist in Tenant"
$HostPool = Get-AzWVDHostPool 
if (!$HostPool.name -contains $HostPoolName)
{
    Write-Log -Error "Host Pool does not exist"
    throw "Host Pool: $HostPoolName does not exist"
}

Write-Log -Message "Host Pool: $HostPoolName exists"

[array]$cloud = @()
[array]$users = @()
if ($defaultUsers) {
    $userlist = $DefaultUsers.Split(",")


    foreach ($user in $userlist) 
    {
        if ($user -match "@") { 
            $users += $user
        } else {
            $cloud += $user
        } 
        
    }
    
    if($cloud.count -gt 0) {
        Write-Log -Message "Adding Cloud Groups"
        foreach ($clouduser in $cloud)
        {
            try {
                Write-Log -Message "Adding user/group: $clouduser to App Group $ApplicationGroupName"
                New-AzRoleAssignment -ObjectId "$($clouduser)" -RoleDefinitionName "Desktop Virtualization User" -ResourceName $ApplicationGroupName -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.DesktopVirtualization/applicationGroups' -ErrorAction Stop
            } catch {
                Write-Log -Error "Error adding user/group: $clouduser to App Group: $ApplicationGroupName"
                Write-Log -Error "Error Details: $_"
            }
        }
    }
    if ($users.count -gt 0) {
        Write-Log -Message "Adding On-Premise Users/Groups"
        foreach ($premUser in $users) 
        {
            try {
                Write-Log -Message "User: $premuser"
                New-AzRoleAssignment -UserPrincipalName "$premUser" -RoleDefinitionName "Desktop Virtualization User" -ResourceName $ApplicationGroupName -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.DesktopVirtualization/applicationGroups' -ErrorAction Stop
                Write-Log -Message "Default User Group successfully added to App Group: $ApplicationGroupName"
            } catch {
                Write-Log -Error "Error adding user: $premUser to App Group: $ApplicationGroupName"
                Write-Log -Error "Error details: $_"
            }
        }
    }
} 

