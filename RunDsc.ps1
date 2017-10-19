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

$scriptBlock = {
    Set-PSRepository -InstallationPolicy Trusted -Name PSGallery
    Install-Module xActiveDirectory
    Install-Module xComputerManagement
    Install-Module xPSDesiredStateConfiguration
    Install-Module xNetworking -RequiredVersion 5.2.0.0
    Install-Module xDnsServer -RequiredVersion 1.6.0.0
}

# TODO: something to ensure the above modules are installed

$administratorCredential = New-PSCredential -Username vagrant -PlaintextPassword 'vagrant'
$domainAdministratorCredential = New-PSCredential -Username STORAGE\storageadmin -PlaintextPassword 'testtest1234!'

Write-Output 'Configuring the local configuration manager on the domain controller...'
Invoke-DscConfiguration `
    -Configuration (Get-Command LCMConfig) `
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
            ComputerName = 'fs1'
        }
    )
}

Invoke-DscConfiguration `
    -Configuration (Get-Command LCMConfig) `
    -ConfigurationData $fileServerConfigurationData `
    -Credential $administratorCredential `
    -Verbose


# Invoke-Command -ScriptBlock $scriptBlock `
#     -Credential $administratorCredential -ComputerName $ips.fileserver1 -Verbose

Invoke-DscConfiguration `
    -Configuration (Get-Command FileServer) `
    -ConfigurationData $fileServerConfigurationData `
    -Credential $administratorCredential `
    -Verbose
# FileServer `
#     -ConfigurationData $fileServerConfigurationData `
#     -OutputPath FileServer
# Start-DscConfiguration -Path FileServer -Force -Wait -Credential $administratorCredential

