Disconnect-Graph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes DeviceManagementManagedDevices.ReadWrite.All, Directory.Read.All

# No longer needed in Graph SDK V2
# Select-MgProfile -Name beta

# Filter for Lenovo devices
$managedDevices = Get-MgDeviceManagementManagedDevice -Filter "Manufacturer eq 'LENOVO'"

<#

Variables for MTM to Friendly Name
https://github.com/damienvanrobaeys/Lenovo_Models_Reference/blob/main/MTM_to_FriendlyName.ps1

#>

$URL = "https://download.lenovo.com/luc/bios.txt#"
$Get_Web_Content = (Invoke-WebRequest -Uri $URL).Content
$Models = $Get_Web_Content -split "`r`n"

foreach ($device in $managedDevices) {
    
    $deviceNotes = (Get-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id -Property "Notes").Notes
    $Mtm = $device.Model.Substring(0, 4).Trim()
    $FamilyName = $(foreach ($Model in $Models) { 
            if ($Model.Contains($Mtm)) { 
                if ($Model.Contains("Type")) {
                    $Model.Split("Type")[0]
                }
                else {
                    $Model.Split("=")[0]
                }
            }
        }) | Sort-Object -Unique
    
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