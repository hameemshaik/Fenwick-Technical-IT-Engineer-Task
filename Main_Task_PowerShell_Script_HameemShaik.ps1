# Script to deploy a Windows IIS Server on Azure with the following specifications:
    # 1. Pick an appropriate Windows Server image to support Hotpatching.
    # 2. Pick an appropriate size for a small IIS server (1-5 users, static website) with very low average CPU.
    # 3. Deploy within the Australia East region. 
    # 4. Use an appropriate subnetting scheme for approximately 20 related machines.
    # 5. Make sure the machine is secure with only secure public web access.
    # 6. Create and apply an appropriate backup policy.



#Prerequisites:

$PSVersionTable <# To check the version of PowerShell that is currently installed on system. #>
Install-Module -Name Az -AllowClobber <# To pull and install Azure PowerShell module. #>
Update-Module -Name Az <# To update Azure PowerShell module. #>
Get-Module -ListAvailable <# To check all the installed Az modules. #>
Connect-AzAccount <# To establish a connection to Microsoft Azure using Azure account credentials. #>


  
# Variables declaration:

$resourceGroupName = "rG01"
$locationName = "australiaeast" <# 3. Deploy within the Australia East region. #>
$virtualNetworkName = "vNet01"
$subnetName = "sNet01"
$publicIPName = "pIP01"
$publicIPAllocationMethod = "Static"
$networkSecurityGroupName = "nSG01"
$ruleName = "allowHTTPS"
$networkInterfaceCardName = "nIC01"
$vMImage = "MicrosoftWindowsServer:WindowsServer:2019-datacenter-smalldisk:latest" <# 1. Appropriate Windows Server image which supports Hotpatching. #>
$vMName = "vM01"
$vMSize = "Standard_DS2_v2" <# 2. Appropriate size for a small IIS server (1-5 users, static website) with very low average CPU. #>
$vaultName = "vault01"



# Resource group creation.

$rG01 = New-AzResourceGroup `
            -Name $resourceGroupName `
               -Location $locationName

Get-AzResourceGroup <# Shows all available resource groups. #>



# Virtual network creation.

$vNet01 = New-AzVirtualNetwork `
            -Name $virtualNetworkName `
            -ResourceGroupName $resourceGroupName `
            -Location $locationName `
            -AddressPrefix "10.0.0.0/24" <# /24 provides 254 usable hosts excluding network and broadcast addresses. #>

Get-AzVirtualNetwork `
    -Name $virtualNetworkName <# Shows the created virtual network. #>



# Subnet creation within the virtual network which supports 20 hosts - specified as an object.

$sNet01 = Add-AzVirtualNetworkSubnetConfig `
            -Name $subnetName `
            -VirtualNetwork $vNet01 `
            -AddressPrefix "10.0.0.0/27" <# 4. /27 provides 30 usabe hosts in this subnet (supports 20 related machines) excluding network and broadcast addresses. #>

Get-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -VirtualNetwork $vNet01 <# Shows the created subnet. #>



$sNet01 | Set-AzVirtualNetwork <# Associate sNet01 to vNet01. #>



# Public IP address creation with static IP allocation.

$pIP01 = New-AzPublicIpAddress `
            -Name $publicIPName `
            -ResourceGroupName $resourceGroupName `
            -Location $locationName `
            -AllocationMethod $publicIPAllocationMethod

Get-AzPublicIPAddress <# Shows all available public IP addresses. #>



# Network security group creation.

$nSG01 = New-AzNetworkSecurityGroup `
        -Name $networkSecurityGroupName `
        -ResourceGroupName $resourceGroupName `
        -Location $location

Get-AzNetworkSecurityGroup <# Shows all available network security groups. #>



# Associating network seurity group: nSG01 to the subnet: sNet01.

$sNet01.NetworkSecurityGroup = $nSG01
Set-AzVirtualNetwork `
    -VirtualNetwork $vNet01



# Adding a rule to the network security group - 5. To Make sure the machine is secure with only secure public web access.

$nSG01 | Add-AzNetworkSecurityRuleConfig ` 
            -Name $ruleName `
            -Description "Allow port 443 for secure webserver access" `
	        -Access Allow `
	        -Protocol Tcp `
            -Direction Inbound `
            -Priority 100 `
            -SourceAddressPrefix Internet `
            -SourcePortRange 443 `
	        -DestinationAddressPrefix * `
	        -DestinationPortRange 443 | Set-AzNetworkSecurityGroup

Get-AzNetworkSecurityRuleConfig `
    -NetworkSecurityGroup $nSG01 <# Shows all available network security rules in the security group: nSG01. #>



# Create a virtual network interface.

$nIC01 = New-AzNetworkInterface `
            -Name $networkInterfaceCardName `
            -ResourceGroupName $resourceGroupName `
            -Location $locationName `
            -SubnetId $vNet01.Subnets[0].Id `
            -PublicIpAddressId $publicIpName.Id `
            -NetworkSecurityGroupId $networkSecurityGroupName.Id

Get-AzNetworkInterface <# Shows all available network interfaces. #>



# Virtual machine creation.

$vM01 = New-AzVM `
        -ResourceGroupName $resourceGroupName `
        -Name $vMName `
        -Size $vMSize `
        -Location $locationName `
        -VirtualNetworkName $virtualNetworkName `
        -SubnetName $subnetName `
        -SecurityGroupName $networkSecurityGroupName `
        -PublicIpAddressName $publicIpName `
        -ImageName $vMImage   

Get-AzVM <# Shows all available virtual machines. #>



# Vault creation.

Get-AzVM `
    -ResourceGroupName $resourceGroupName

$vault01 = New-AzRecoveryServicesVault `
            -Name $vaultName `
            -ResourceGroupName $resourceGroupName `
            -Location $locationName

Get-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $resourceGroupName <# Shows all available vaults. #>



#Vault context.

Set-AzRecoveryServicesVaultContext `
    -Vault $vault01



#Backup replication.

Set-AzRecoveryServicesBackupProperty `
    -Vault $vault01 `
    -BackupStorageRedundancy LocallyRedundant



# Getting the backup policy.

$backUpPolicy01 = Get-AzRecoveryServicesBackupProtectionPolicy `
                    -Name "DefaultPolicy"



# Associating backup policy to virtual machine: vM01

Enable-AzRecoveryServicesBackupProtection `
    -Policy $backUpPolicy01 `
    -Name $vMName `
    -ResourceGroupName $resourceGroupName



# Virtual machine backup

$container = Get-AzRecoveryServicesBackupContainer `
                -ContainerType AzureVM `
                -FriendlyName $vMName



# To retrieve the backup items associated with the container: $containet and workload type.

$item = Get-AzRecoveryServicesBackupItem `
            -Container $container `
            -WorkloadType AzureVM



# To initiate the backup operation for a the backup item: $item.
Backup-AzRecoveryServicesBackupItem `
    -Item $item

Get-AzRecoveryServicesBackupJob <# # To verify the backup process. #>



<#Additional Question: Troubleshooting connections from legacy devices. 

Some legacy devices cannot connect to this new web server.  

Why might this be?  

What’s the best workaround?   

  
Possible Causes: 

Outdated or incompatible protocols: Legacy devices use outdated protocols not supported by the new web server. 

Firewall or network restrictions: Legacy devices are blocked by firewalls or network restrictions. 


Best Workaround: 

Enable support for older protocols: Configure the server to allow connections using older protocols (e.g., TLS 1.0, SSL 3.0). 

Update firmware or software on legacy devices. 

Implement a reverse proxy: Set up a reverse proxy server between legacy devices and the new web server. Proxy server handles protocol negotiation on behalf of legacy devices. #>
