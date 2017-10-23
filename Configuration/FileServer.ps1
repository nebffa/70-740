$ErrorActionPreference = 'Stop'


configuration FileServer
{
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName xNetworking

    Node $AllNodes.NodeName
    {
        xWindowsFeature FileServer
        {
            Name = 'FileAndStorage-Services'
            IncludeAllSubFeature = $true
        }

        xDnsServerAddress DNSServer {
            Address        = $Node.DnsServerAddress
            InterfaceAlias = "Ethernet"
            AddressFamily = "IPV4"
        }

        xWaitForADDomain WaitForDomain
        {
            DomainName = $Node.DomainName
            RetryCount = 5
            RetryIntervalSec = 5
            DependsOn = '[xDnsServerAddress]DNSServer'
        }

        xComputer ComputerName 
        {
            Name = $Node.ComputerName
            DomainName = $Node.DomainName
            JoinOU = $Node.JoinOU
            Credential = $Node.DomainCredential
            DependsOn = '[xWaitForADDomain]WaitForDomain'
        }
    }
}
