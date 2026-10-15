

$DEFAULT_PASSWORD = "3SXI@lab"

$NestedESXiHostnameToIPs = @(
    @{
        VMName   = "labesx09"
        FQDN = "labesx09.lanz.lab.ncl"
        Hostname = "labesx09.lanz"
        IP_LAN = "10.100.51.159"
        IP_SAN = "192.168.20.159"
    },
    @{
        VMName   = "labesx10"
        FQDN = "labesx10.lanz.lab.ncl"
        Hostname = "labesx10.lanz"
        IP_LAN = "10.100.51.160"
        IP_SAN = "192.168.20.160"
    }
)

# Physical ESXi host or vCenter Server to deploy vSphere 6.5 lab
$VIServer = "labesxvc01v.lab.ncl"
$VIUsername = "administrator@vsphere.local"
$VIPassword = "3SXI@lab"


# Specifies whether deployment is to an ESXi host or vCenter Server
# Use either ESXI or VCENTER
$DeploymentTarget = "ESXI"

# Full Path to both the Nested ESXi 6.5 VA + extracted VCSA 6.5 ISO
# $NestedESXiApplianceOVA = "E:\DEPOT\PROD\COMP\ESX_HOST\Nested_ESXi9.1.0.0_Appliance_Template_v1.0.ova"
$NestedESXiApplianceOVA = "E:\DEPOT\PROD\COMP\ESX_HOST\Nested_ESXi9.0.2_Appliance_Template_v1.0.ova"

#Nested ESXi Bootstrap Node
# $bootStrapNode = "10.100.51.156"

# Nested ESXi VM Resources
$PORTGROUP_NESTED_ESXI_LAN = "nested_vcf_lan"
$PORTGROUP_NESTED_ESXI_SAN = "nested_vsan"
$NestedESXivCPU = "24"
$NestedESXivMEM = "368" #GB
$NestedESXiCachingvDisk = "16" #GB
$NestedESXiCapacityvDisk = "200" #GB

# General Deployment Configuration for both Nested ESXi VMs
$VMNetwork = "nested_vcf_lan"
$VMDatastore = "NESTEDESXI-OS"
$VMDatacenter = "LAB"
$VMNetmask = "255.255.255.0"
$VMGateway = "10.100.51.1"
$VMDNS = "10.255.50.24"
$VMNTP = "ntp.lab.ncl"
$VMVLAN = 251
$VMPassword = $DEFAULT_PASSWORD
$VMDomain = "lanz.lab.ncl"
$VMSyslog = ""
# Applicable to Nested ESXi only
$VMSSH = "true"
$VMVMFS = "false"


#### DO NOT EDIT BEYOND HERE ####

$verboseLogFile = "vsphere90-lab-deployment.log"
$vSphereVersion = "9.0.2"
$deploymentType = "Self Managed"
$random_string = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$VAppName = "Nested-vSphere-Lab-$vSphereVersion-$random_string"

$preCheck = 1
$confirmDeployment = 1
$deployNestedESXiVMs = 1
$bootStrapFirstNestedESXiVM = 1
$deployVCSA = 1
$setupNewVC = 1
$addESXiHostsToVC = 1
$configureVSANDiskGroups = 1
$clearVSANHealthCheckAlarm = 1
$moveVMsIntovApp = 1

#### EXECUTION INITIATED

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -ParticipateInCeip $false -Confirm:$false | Out-Null


$StartTime = Get-Date

Function MyLogger {
    param(
    [Parameter(Mandatory=$true)]
    [String]$message
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor Green " $message"
    $logMessage = "[$timeStamp] $message"
    $logMessage | Out-File -Append -LiteralPath $verboseLogFile
}

if($preCheck -eq 1) {
    if(!(Test-Path $NestedESXiApplianceOVA)) {
        Write-Host -ForegroundColor Red "`nUnable to find $NestedESXiApplianceOVA ...`nexiting"
        exit
    }
}


### VALIDATION
## ADD LATER
##############

if($deployNestedESXiVMs -eq 1) {
    MyLogger "Connecting to $VIServer ..."
    $viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue

    if($DeploymentTarget -eq "ESXI") {
        $datastore = Get-Datastore -Server $viConnection -Name $VMDatastore
        $vmhost = Get-VMHost -Server $viConnection
        $network = Get-VirtualPortGroup -Server $viConnection -Name $VMNetwork -VMHost $vmhost

        if($datastore.Type -eq "vsan") {
            MyLogger "VSAN Datastore detected, enabling Fake SCSI Reservations ..."
            Get-AdvancedSetting -Entity $vmhost -Name "VSAN.FakeSCSIReservations" | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    } else {
        $datastore = Get-Datastore -Server $viConnection -Name $VMDatastore | Select -First 1
        $network = Get-VirtualPortGroup -Server $viConnection -Name $VMNetwork | Select -First 1
        $cluster = Get-Cluster -Server $viConnection -Name $VMCluster
        $datacenter = $cluster | Get-Datacenter
        $vmhost = $cluster | Get-VMHost | Select -First 1
    }

    if($DeploymentTarget -eq "ESXI") {
        $NestedESXiHostnameToIPs | Sort-Object -Property VMName | Foreach-Object {
            $VMName = $_.VMName
            $VMIPAddress = $_.IP_LAN
            $VMFQDN = $_.FQDN

            $ovfconfig = Get-OvfConfiguration $NestedESXiApplianceOVA
            $networkMapLabel = ($ovfconfig.ToHashTable().keys | Where-Object {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
            $ovfconfig.NetworkMapping.$networkMapLabel.value = $VMNetwork

            $ovfconfig.common.guestinfo.hostname.value = $VMFQDN
            $ovfconfig.common.guestinfo.ipaddress.value = $VMIPAddress
            $ovfconfig.common.guestinfo.vlan.value = $VMVLAN
            $ovfconfig.common.guestinfo.netmask.value = $VMNetmask
            $ovfconfig.common.guestinfo.gateway.value = $VMGateway
            $ovfconfig.common.guestinfo.dns.value = $VMDNS
            $ovfconfig.common.guestinfo.domain.value = $VMDomain
            $ovfconfig.common.guestinfo.ntp.value = $VMNTP
            $ovfconfig.common.guestinfo.syslog.value = $VMSyslog
            $ovfconfig.common.guestinfo.password.value = $VMPassword
            if($VMSSH -eq "true") {
                $VMSSHVar = $true
            } else {
                $VMSSHVar = $false
            }
            $ovfconfig.common.guestinfo.ssh.value = $VMSSHVar

            MyLogger "Deploying Nested ESXi VM $VMName ..."
            $vm = Import-VApp -Source $NestedESXiApplianceOVA -OvfConfiguration $ovfconfig -Name $VMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

            MyLogger "Updating VM Network ..."
            foreach($networkAdapter in ($vm | Get-NetworkAdapter))
            {
                MyLogger "Configuring adapter $networkAdapter in $vm"
                $networkAdapter | Set-NetworkAdapter -Portgroup $network -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
                Start-Sleep 10
            }
            $vm = Get-VM -Server $viConnection -Name $VMName
            MyLogger "Configuring adapter Network adapter SAN 1 in $vm"
            $vm | New-NetworkAdapter -NetworkName $PORTGROUP_NESTED_ESXI_SAN -Type Vmxnet3 -StartConnected -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
            MyLogger "Configuring adapter Network adapter SAN 2 in $vm"
            $vm | New-NetworkAdapter -NetworkName $PORTGROUP_NESTED_ESXI_SAN -Type Vmxnet3 -StartConnected -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

            MyLogger "Updating vCPU Count to $NestedESXivCPU & vMEM to $NestedESXivMEM GB ..."
            Set-VM -Server $viConnection -VM $vm -NumCpu $NestedESXivCPU -MemoryGB $NestedESXivMEM -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

            MyLogger "Powering On $vmname ..."
            Start-VM -Server $viConnection -VM $vm -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    } else {
        $NestedESXiHostnameToIPs | Sort-Object -Property VMName | Foreach-Object {
            $VMName = $_.VMName
            $VMIPAddress = $_.IP_LAN
            $VMFQDN = $_.FQDN
            $VMIPSAN = $_.IP_SAN

            $ovfconfig = Get-OvfConfiguration $NestedESXiApplianceOVA
            $networkMapLabel = ($ovfconfig.ToHashTable().keys | Where-Object {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
            $ovfconfig.NetworkMapping.$networkMapLabel.value = $VMNetwork

            $ovfconfig.common.guestinfo.hostname.value = $VMFQDN
            $ovfconfig.common.guestinfo.ipaddress.value = $VMIPAddress
            $ovfconfig.common.guestinfo.vlan.value = $VMVLAN
            $ovfconfig.common.guestinfo.netmask.value = $VMNetmask
            $ovfconfig.common.guestinfo.gateway.value = $VMGateway
            $ovfconfig.common.guestinfo.dns.value = $VMDNS
            $ovfconfig.common.guestinfo.domain.value = $VMDomain
            $ovfconfig.common.guestinfo.ntp.value = $VMNTP
            $ovfconfig.common.guestinfo.syslog.value = $VMSyslog
            $ovfconfig.common.guestinfo.password.value = $VMPassword
            if($VMSSH -eq "true") {
                $VMSSHVar = $true
            } else {
                $VMSSHVar = $false
            }
            $ovfconfig.common.guestinfo.ssh.value = $VMSSHVar

            MyLogger "Deploying Nested ESXi VM $VMName ..."
            $vm = Import-VApp -Source $NestedESXiApplianceOVA -OvfConfiguration $ovfconfig -Name $VMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

            MyLogger "Updating VM Network ..."
            foreach($networkAdapter in ($vm | Get-NetworkAdapter))
            {
                MyLogger "Configuring adapter $networkAdapter in $vm"
                $networkAdapter | Set-NetworkAdapter -Portgroup $network -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
                Start-Sleep 10
            }
            $vm = Get-VM -Server $viConnection -Name $VMName
            MyLogger "Configuring adapter Network adapter SAN 1 in $vm"
            $vm | New-NetworkAdapter -NetworkName $PORTGROUP_NESTED_ESXI_SAN -Type Vmxnet3 -StartConnected -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
            MyLogger "Configuring adapter Network adapter SAN 2 in $vm"
            $vm | New-NetworkAdapter -NetworkName $PORTGROUP_NESTED_ESXI_SAN -Type Vmxnet3 -StartConnected -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

            MyLogger "Updating vCPU Count to $NestedESXivCPU & vMEM to $NestedESXivMEM GB ..."
            Set-VM -Server $viConnection -VM $vm -NumCpu $NestedESXivCPU -MemoryGB $NestedESXivMEM -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

            MyLogger "Powering On $vmname ..."
            Start-VM -Server $viConnection -VM $vm -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

            MyLogger "Powering On $vmname ..."
            $vm | Start-Vm -RunAsync | Out-Null
        }
    }

    if($moveVMsIntovApp -eq 1 -and $DeploymentTarget -eq "VCENTER") {
        # Check whether DRS is enabled as that is required to create vApp
        if((Get-Cluster -Server $viConnection $cluster).DrsEnabled) {
            MyLogger "Creating vApp $VAppName ..."
            $VApp = New-VApp -Name $VAppName -Server $viConnection -Location $cluster

            if($deployNestedESXiVMs -eq 1) {
                MyLogger "Moving Nested ESXi VMs into $VAppName vApp ..."
                $NestedESXiHostnameToIPs | Sort-Object -Property IP_LAN | Foreach-Object {
                    $vm = Get-VM -Name $_.VMName -Server $viConnection
                    Move-VM -VM $vm -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
                }
            }
        } else {
            MyLogger "vApp $VAppName will NOT be created as DRS is NOT enabled on vSphere Cluster ${cluster} ..."
        }
    }

    MyLogger "Disconnecting from $VIServer ..."
    Disconnect-VIServer $viConnection -Confirm:$false
}

$NestedESXiHostnameToIPs | ForEach-Object {
    $ESX_HOST = $_.FQDN
    $VM_VLAN = $_.VLAN

    MyLogger "Connecting to $ESX_HOST ..."

    $vESXi = Connect-VIServer $ESX_HOST -User root -Password $VIPassword -WarningAction SilentlyContinue

    $esxcli = Get-EsxCli -Server $vESXi -V2

    MyLogger "Configuring Portgroup VM Network on $ESX_HOST with VLAN $VM_VLAN ..."
    $argsVSS = $esxcli.network.vswitch.standard.portgroup.set.CreateArgs()
    $argsVSS.portgroupname = "VM Network"
    $argsVSS.vlanid = $VM_VLAN

    $esxcli.network.vswitch.standard.portgroup.set.Invoke($argsVSS) | Out-Null
}

$EndTime = Get-Date
