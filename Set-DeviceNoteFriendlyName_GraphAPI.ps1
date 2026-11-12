#requires -Module Microsoft.Graph.Authentication

Connect-MgGraph -Scopes DeviceManagementManagedDevices.ReadWrite.All, Directory.Read.All

# Define constants
$endpoint = "https://graph.microsoft.com"
$version = "beta"
$resource = "deviceManagement/managedDevices"
$query = "?`$filter=manufacturer eq 'LENOVO'"
$query2 = "?`$select=notes"

# Query managed Lenovo devices via Microsoft Graph API
$devicesRequest = @{
    Uri    = "$($endpoint)/$($version)/$($resource)$($query)"
    Method = "GET"
}

try
{
    # Follow @odata.nextLink until every page of devices has been retrieved
    $managedDevices = [System.Collections.Generic.List[object]]::new()
    do
    {
        $response = Invoke-MgGraphRequest @devicesRequest
        if ($response.value) { $managedDevices.AddRange([object[]]$response.value) }
        $devicesRequest.Uri = $response.'@odata.nextLink'
    } while ($devicesRequest.Uri)
}
catch
{
    Write-Error "Failed to retrieve managed devices: $($_.Exception.Message)"
    return
}

<#
Variables for MTM to Friendly Name
https://github.com/damienvanrobaeys/Lenovo_Models_Reference/blob/main/MTM_to_FriendlyName.ps1
#>
$URL = "https://download.lenovo.com/luc/bios.txt#"
$Get_Web_Content = (Invoke-WebRequest -Uri $URL).Content
$Models = $Get_Web_Content -split "`r`n"

foreach ($device in $managedDevices)
{
    $deviceDetailsRequest = @{
        Uri    = "$($endpoint)/$($version)/$($resource)/$($device.id)$($query2)"
        Method = "GET"
    }

    try
    {
        $deviceDetails = Invoke-MgGraphRequest @deviceDetailsRequest
    }
    catch
    {
        Write-Error "Failed to retrieve device details for device ID $($device.id): $($_.Exception.Message)"
        continue
    }

    $deviceNotes = $deviceDetails.notes
    $Mtm = if ($device.model.Length -ge 4) { $device.model.Substring(0, 4).Trim() } else { $device.model.Trim() }
    [string]$FamilyName = $(foreach ($Model in $Models)
        {
            if ($Model.Contains($Mtm))
            {
                if ($Model.Contains("Type"))
                {
                    $Model.Split("Type")[0]
                }
                else
                {
                    $Model.Split("=")[0]
                }
            }
        }) | Sort-Object -Unique

    if ([string]::IsNullOrWhiteSpace($FamilyName))
    {
        Write-Warning "Model $($device.model) for device ID $($device.id) was not found in the catalog. Skipping."
        continue
    }

    $notesRequest = @{
        Uri    = "$($endpoint)/$($version)/$($resource)/$($device.id)"
        Method = "PATCH"
    }

    if ([string]::IsNullOrEmpty($deviceNotes))
    {
        # Update Device notes
        $notesRequest.Body = (@{ notes = $FamilyName } | ConvertTo-Json -Compress)
        try
        {
            Invoke-MgGraphRequest @notesRequest
            Write-Output "Updated notes for device ID $($device.id) to $($FamilyName)"
        }
        catch
        {
            Write-Error "Failed to update notes for device ID $($device.id): $($_.Exception.Message)"
        }
    }
    elseif ($deviceNotes -notmatch $FamilyName)
    {
        $appendDeviceNote = $deviceNotes + "`n$FamilyName"
        $notesRequest.Body = (@{ notes = $appendDeviceNote } | ConvertTo-Json -Compress)
        try
        {
            Invoke-MgGraphRequest @notesRequest
            Write-Output "Appended notes for device ID $($device.id) with $($FamilyName)"
        }
        catch
        {
            Write-Error "Failed to append notes for device ID $($device.id): $($_.Exception.Message)"
        }
    }
    else
    {
        Write-Output "No update needed for device ID $($device.id)"
    }
}