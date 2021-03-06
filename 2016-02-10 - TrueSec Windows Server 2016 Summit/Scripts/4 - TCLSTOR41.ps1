﻿$CMPs = "TCLSTOR41","TCLSTOR42","TCLSTOR43","TCLSTOR44"
$ClusterName = "TCLSTOR40"
$ClusterFQDN = $ClusterName+"."+$env:USERDNSDOMAIN
$StoragePool = "stPool01"
$vDisk = "vDisk01"
$vDisk2 = "vDisk02"
$SOFS = "sofs01"


foreach ($Node in $CMPs) { 
Install-WindowsFeature –Name File-Services, Failover-Clustering –IncludeManagementTools
}


#Validate cluster
Test-Cluster –Node $CMPs –Include “Storage Spaces Direct”,"Inventory","Network",”System Configuration” -verbose


# Create a New Cluster 
New-Cluster –Name $ClusterName –Node $CMPs –NoStorage -verbose

# Enable Storage Spaces Direct 
Enable-ClusterS2D -Verbose 

# Create a Stroage Pool 
$Pool = New-StoragePool  -StorageSubSystemName $ClusterFQDN -FriendlyName $StoragePool -WriteCacheSizeDefault 0 -ProvisioningTypeDefault Fixed -ResiliencySettingNameDefault Mirror -PhysicalDisk (Get-StorageSubSystem  -Name $ClusterFQDN | Get-PhysicalDisk | ? CanPool -eq $true) -Verbose

# GRATZ! You are running virtual and can CHEAT!!! 
Get-StoragePool $StoragePool | Get-PhysicalDisk | where PhysicalLocation -like "*Slot 1" | Set-PhysicalDisk -MediaType SSD
Get-StoragePool $StoragePool | Get-PhysicalDisk |? MediaType -eq SSD | Set-PhysicalDisk -Usage Journal

#Create virtual disks
$Volume1 = New-Volume -StoragePoolFriendlyName $StoragePool -FriendlyName $vDisk -PhysicalDiskRedundancy 2 -FileSystem CSVFS_REFS –Size 20GB -Verbose 
$Volume1 = New-Volume -StoragePoolFriendlyName $StoragePool -FriendlyName $vDisk2 -PhysicalDiskRedundancy 2 -FileSystem CSVFS_REFS –Size 20GB -Verbose 

#Disable ReFS Integrity Streams by Default on Volume
#Can be Re-enabled on Individual Files or Folders as Desired
$ClusterStorageDir = get-childitem c:\ClusterStorage
$VolumeDir = "c:\ClusterStorage\"+"$ClusterStorageDir"
Set-FileIntegrity "C:\ClusterStorage\Volume1" –Enable $false -Verbose
Set-FileIntegrity "C:\ClusterStorage\Volume2" –Enable $false -Verbose

# Create a SOFS Resource 
New-StorageFileServer -StorageSubSystemName $ClusterFQDN -FriendlyName $SOFS -HostName $SOFS -Protocols SMB -Verbose

# Create a SOFS Share
$ShareDir = md C:\ClusterStorage\Volume1\SOFSShare2
New-SmbShare -Name Share01 -Path $ShareDir -FullAccess Everyone
Set-SmbPathAcl -ShareName Share01

# Cloud Witness
# Set-ClusterQuorum –CloudWitness –AccountName tdwitness -AccessKey 'CnJjYExzYTCCcoeJhTJXvrWAKklhFyyR56AxtnoZYkosthlESOoslnHbhzDS7x6VRaJI+tRliA==' -verbose


