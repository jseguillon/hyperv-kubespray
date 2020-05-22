Param ( [String]$vmName = $(throw "-vmName is required."),
        [String]$macAddrCtrlPlane = $(throw "-macAddrCtrlPlane is required."))

$countItf=(Get-VMNetworkAdapter -VMName $vmName | Where-Object {$_.MacAddress -match $macAddrCtrlPlane}).count

If ($countItf -ne 1) {
  echo "Stop vm $vmName"
  Stop-VM -VMName $vmName 
  sleep 2
  echo "Add itf  $macAddrCtrlPlane to vm $vmName"
  Add-VMNetworkAdapter -VMName $vmName -SwitchName "Default Switch"  -StaticMacAddress $macAddrCtrlPlane
  sleep 2
  echo "Starting again vm  $vmName"
  Start-VM -VMName $vmName
  sleep 2
  echo "Vm now ready"
}
Else {
  echo "Itf already on this VM"
}

# dont'forget to : `Set-ExecutionPolicy unrestricted` prior to exec
