# AutoNtwrk.ps1 
# Contributors: Chris McLernon
# Description: Automates Network Checks for Tablets on Windows 11

# Configuration
$correctSSID = "SpectrumSetup-ED"
$waitBeforeReconnectSeconds = 5

# Relaunch script as admin if not already elevated
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Re-launching script with Administrator privileges..."

    $scriptPath = $PSCommandPath
    Start-Process "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-Command", "& {cd '$currentDirectory'; & '$scriptPath'}" -Verb RunAs
    exit 1
}

# Function to get current SSID
function Get-CurrentSSID {
    $ssidInfo = netsh wlan show interfaces | Select-String '^\s*SSID\s*:\s*(.+)$'
    if ($ssidInfo) {
        return ($ssidInfo -replace '^\s*SSID\s*:\s*', '').Trim()
    }
    else {
        return $null
    }
}

function Compare-Network {
    # Compare and take action
    if ($currentSSID -ne $correctSSID) {
        Write-Host "Connected to wrong network: '$currentSSID'. Expected: '$correctSSID'."
    
        # Disconnect
        netsh wlan disconnect
        Write-Host "Disconnected from '$currentSSID'."

        # Wait before reconnecting
        Start-Sleep -Seconds $waitBeforeReconnectSeconds

        # Reconnect to correct SSID (profile must exist)
        netsh wlan connect name="$correctSSID"
        Write-Host "Attempting to reconnect to '$correctSSID'..."
    }
    elseif (-not $currentSSID) {
        Write-Host "No Wifi Connection Detected! Reconnecting to '$correctSSID"
    }
    else {
        Write-Host "Already connected to the correct network: '$correctSSID'."
    }
}

try {
    # Get current SSID
    $currentSSID = Get-CurrentSSID

    # Compare and take action
    Compare-Network
}
catch {
    Write-Host "UNHANDLED EXCEPTION: $_"
}