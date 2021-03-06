$ErrorActionPreference = 'Stop'


configuration DomainController
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$ComputerName,
    
        [Parameter(Mandatory=$true)]
        [String]$DomainName,
    
        [Parameter(Mandatory=$true)]
        [PSCredential]$DomainCredential
    )

    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName @{ModuleName='xNetworking'; ModuleVersion='5.2.0.0'}
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName xDnsServer

    Node $AllNodes.NodeName
    {
        LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
  
        xComputer ComputerName 
        {
            Name = $ComputerName
        }

        xWindowsFeature ADDSInstall 
        {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
            DependsOn = '[xComputer]ComputerName'
        }

        xADDomain DC1
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCredential
            SafemodeAdministratorPassword = $DomainCredential
            DependsOn = '[xWindowsFeature]ADDSInstall'
        }

        xDnsServerAddress PrimaryDNSClient {
            Address = $node.NodeName
            InterfaceAlias = 'Ethernet'
            AddressFamily = 'IPV4'
        }

        xDnsServerADZone AddReverseADZone {
            Name = '5.0.10.in-addr.arpa'
            DynamicUpdate = 'Secure'
            ReplicationScope = 'Forest'
            Ensure = 'Present'
            DependsOn = ('[xADDomain]DC1', '[xDnsServerAddress]PrimaryDNSClient')
        }
    }
}
