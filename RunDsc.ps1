Param
(
    [Parameter(Mandatory=$true)]
    [ValidateSet('HyperV', 'Azure')]
    [String]$EnvironmentType,

    [Switch]$Force
)


Import-Module DscExecution -Force


$ErrorActionPreference = 'Stop'


. ./Configuration/DomainController.ps1
. ./Configuration/FileServer.ps1


[DSCLocalConfigurationManager()]
configuration LCMConfig
{
    Node $AllNodes.NodeName
    {
        Settings
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
    }
}


configuration DSCModules
{
    Import-DscResource -ModuleName @{ModuleName='PowerShellModule'; ModuleVersion='0.3'}

    Node $AllNodes.NodeName
    {
        PSModuleResource xActiveDirectory
        {
            Ensure = 'Present'
            Module_Name = 'xActiveDirectory'
            RequiredVersion = '2.16.0.0'
        }

        PSModuleResource xComputerManagement
        {
            Ensure = 'Present'
            Module_Name = 'xComputerManagement'
            RequiredVersion = '3.0.0.0'
        }

        PSModuleResource xPSDesiredStateConfiguration
        {
            Ensure = 'Present'
            Module_Name = 'xPSDesiredStateConfiguration'
            RequiredVersion = '7.0.0.0'
        }

        PSModuleResource xNetworking
        {
            Ensure = 'Present'
            Module_Name = 'xNetworking'
            RequiredVersion = '5.2.0.0'
        }

        PSModuleResource xDnsServer
        {
            Ensure = 'Present'
            Module_Name = 'xDnsServer'
            RequiredVersion = '1.6.0.0'
        }
    }
}


Write-Output 'Getting VM IP addresses...'
if ($EnvironmentType -eq 'HyperV')
{
    $cacheLocation = "$PSScriptRoot\.vagrant\ips.json"
    if (!(Test-Path $cacheLocation) -or $Force)
    {
        $ips = @{
            'dc' = vagrant address dc
            'fileserver1' = vagrant address fileserver-1
            'fileserver2' = vagrant address fileserver-2
            'fileserver3' = vagrant address fileserver-3
        }
        $ips | ConvertTo-Json | Out-File $cacheLocation -Encoding UTF8
    }
    else
    {
        $ips = Get-Content -Path $cacheLocation | ConvertFrom-Json
    }
}
elseif ($EnvironmentType -eq 'Terraform')
{
    $terraformOutput = (terraform output -json) | ConvertFrom-Json
}

$configurationData = @{
    AllNodes = @(
        @{
            NodeName = $ips.dc
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}


# TODO: something to ensure the above modules are installed

$administratorCredential = New-PSCredential -Username vagrant -PlaintextPassword 'vagrant'
$domainAdministratorCredential = New-PSCredential -Username STORAGE\vagrant -PlaintextPassword 'vagrant'

Write-Output 'Configuring the local configuration manager on the domain controller...'
Invoke-DscConfiguration `
    -Configuration (Get-Command LCMConfig) `
    -ConfigurationData $configurationData `
    -Credential $administratorCredential `
    -Verbose

Invoke-DscConfiguration `
    -Configuration (Get-Command DSCModules) `
    -ConfigurationData $configurationData `
    -Credential $administratorCredential `
    -Verbose 

Write-Output 'Configuring the domain controller...'
Invoke-DscConfiguration `
    -Configuration (Get-Command DomainController) `
    -ConfigurationData $configurationData `
    -Credential $administratorCredential `
    -ConfigurationParameters @{
        'ComputerName' = 'dc1'
        'DomainName' = 'STORAGE.com'
        'DomainCredential' = $domainAdministratorCredential
    } `
    -Verbose 

$fileServerConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = '*'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        },

        @{
            NodeName = $ips.fileserver1
            DnsServerAddress = $ips.dc
            DomainName = 'STORAGE.com'
            DomainCredential = $domainAdministratorCredential
            ComputerName = 'fs1'
        },

        @{
            NodeName = $ips.fileserver2
            DnsServerAddress = $ips.dc
            DomainName = 'STORAGE.com'
            DomainCredential = $domainAdministratorCredential
            ComputerName = 'fs2'
        },

        @{
            NodeName = $ips.fileserver3
            DnsServerAddress = $ips.dc
            DomainName = 'STORAGE.com'
            DomainCredential = $domainAdministratorCredential
            ComputerName = 'fs3'
        }
    )
}

Invoke-DscConfiguration `
    -Configuration (Get-Command LCMConfig) `
    -ConfigurationData $fileServerConfigurationData `
    -Credential $administratorCredential `
    -Verbose

Invoke-DscConfiguration `
    -Configuration (Get-Command DSCModules) `
    -ConfigurationData $fileServerConfigurationData `
    -Credential $administratorCredential `
    -Verbose 

Invoke-DscConfiguration `
    -Configuration (Get-Command FileServer) `
    -ConfigurationData $fileServerConfigurationData `
    -Credential $administratorCredential `
    -Verbose
