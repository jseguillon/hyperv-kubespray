Param ( [String]$vmName = $(throw "-vmName is required."),
        [String]$macAddrCtrlPlane = $(throw "-macAddrCtrlPlane is required."))

$countItf=(Get-VMNetworkAdapter -VMName $vmName | Where-Object {$_.MacAddress -match $macAddrCtrlPlane}).count

If ($countItf -ne 1) {
  echo "Adding itf to vm"
  Stop-VM -VMName $vmName
  Add-VMNetworkAdapter -VMName $vmName -SwitchName "Default Switch"  -StaticMacAddress $macAddrCtrlPlane
  Start-VM -VMName $vmName
}
Else {
  echo "Itf already on this VM"
}

# dont'forget to : `Set-ExecutionPolicy unrestricted` prior to exec
