function Handler($context, $inputs) {

    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

    $user =  "administrator@vsphere.local"
    $pass = $inputs.password

    Write-Host "$user + $pass"

    $location = $inputs.$location

    if ($location -eq "Aurora") {
        $vCenter = "labvcwld01v.lanz.lab.ncl"
    } elseif ($location -eq "Blyth") {
        $vCenter = "labvcwld01v.lanz.lab.ncl"
    } else {
        break
    }

    Connect-VIServer -Server $vCenter -Username $user -Password $pass -ErrorAction Stop | Out-Null
    $clusters = Get-Cluster

    return $clusters.Name

}
