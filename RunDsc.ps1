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


$terraformOutput = (terraform output -json) | ConvertFrom-Json
$configurationData = @{
    AllNodes = @(
        @{
            NodeName = $terraformOutput.public_ips.value[0]
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
    Install-Module xNetworking
    Install-Module xDnsServer -RequiredVersion 1.6.0.0
}

$administratorCredential = New-PSCredential -Username storageadmin -PlaintextPassword 'testtest1234!'
$domainAdministratorCredential = New-PSCredential -Username STORAGE\storageadmin -PlaintextPassword 'testtest1234!'
Invoke-Command -ScriptBlock $scriptBlock `
    -Credential $administratorCredential -ComputerName $terraformOutput.public_ips.value[0]
LCMConfig -ConfigurationData $configurationData -OutputPath LCMConfig
Set-DscLocalConfigurationManager -Force -Path LCMConfig -Credential $administratorCredential

DomainController `
    -ComputerName dc1 `
    -DomainName 'STORAGE.com' `
    -DomainCredential $administratorCredential `
    -ConfigurationData $configurationData `
    -OutputPath DomainController

Start-DscConfiguration -Path DomainController -Force -Wait -Credential $administratorCredential

$fileServerConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = '*'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        },

        @{
            NodeName = $terraformOutput.public_ips.value[1]
            DnsServerAddress = $terraformOutput.public_ips.value[0]
            DomainName = 'STORAGE.com'
            DomainCredential = $domainAdministratorCredential
            ComputerName = 'fs1'
        }
    )
}

LCMConfig -ConfigurationData $fileServerConfigurationData -OutputPath LCMConfig
Set-DscLocalConfigurationManager -Force -Path LCMConfig -Credential $administratorCredential
Invoke-Command -ScriptBlock $scriptBlock `
    -Credential $administratorCredential -ComputerName $terraformOutput.public_ips.value[1]
Invoke-DscConfiguration `
    -ConfigurationName 'FileServer' `
    -ConfigurationData $fileServerConfigurationData `
    -Credential $administratorCredential
# FileServer `
#     -ConfigurationData $fileServerConfigurationData `
#     -OutputPath FileServer
# Start-DscConfiguration -Path FileServer -Force -Wait -Credential $administratorCredential

