Disconnect-Graph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes DeviceManagementManagedDevices.ReadWrite.All, Directory.Read.All
Select-MgProfile -Name beta

# Filter for Lenovo devices
$managedDevices = Get-MgDeviceManagementManagedDevice -Filter "Manufacturer eq 'LENOVO'"

<#

Variables for MTM to Friendly Name
https://github.com/damienvanrobaeys/Lenovo_Models_Reference/blob/main/MTM_to_FriendlyName.ps1

#>

$URL = "https://download.lenovo.com/bsco/schemas/list.conf.txt"
$Get_Web_Content = Invoke-RestMethod -Uri $URL -Method GET
$Get_Models = ($Get_Web_Content -split "`r`n")

foreach ($device in $managedDevices) {
    
    $deviceNotes = (Get-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id -Property "Notes").Notes
    $Mtm = $device.Model.Substring(0, 4).Trim()
    $FamilyName = ($Get_Models | Where-Object { $_ -like "*$Mtm*" }).Split("(")[0]
    
    if ([string]::IsNullOrEmpty($deviceNotes)) {

        # Update Device notes
        Update-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id -Notes $FamilyName

    }
    elseif ($deviceNotes -notmatch $FamilyName) {
        
        $appendDeviceNote = $deviceNotes + "`n$FamilyName"
        Update-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id -Notes $appendDeviceNote
    }
}

<#

# Output the results
foreach ($device in $managedDevices) {
    $deviceNotes = (Get-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id -Property "Notes").Notes
    Write-Output -InputObject "$($device.DeviceName) is a $($deviceNotes)"
}

#>