# AutoNtwrk.ps1 
# Contributors: Chris McLernon
# Description: Automates Network Checks for Tablets on Windows 11

# Configuration
$correctSSID = "SpectrumSetup-ED"
$waitBeforeReconnectSeconds = 5
$logDate = Get-Date -Format "MMddyyyy_HH_mm_ss"

function New-Log {
    $logFolder = "$PSScriptRoot\tsLogs"
    if (-not (Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder | Out-Null
    }

    $script:logFile = Join-Path $logFolder "tslog_${logDate}.txt"
    Start-Transcript -Path $logFile -Append > $null
}

function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "[MM-dd-yyyy | HH:mm:ss]"
    Write-Host "$timestamp $Message"
}

function Close-Triage { 
    Stop-Transcript > $null
    Write-Host "`nPress any key to close..."
    [void][System.Console]::ReadKey($true)
}
function Compare-Elevation {
    # Relaunch script as admin if not already elevated
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

        Write-Log "Re-launching script with Administrator privileges..."

        $scriptPath = $PSCommandPath
        Start-Process "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-Command", "& {cd '$currentDirectory'; & '$scriptPath'}" -Verb RunAs
        exit 1
    }
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
    if (-not $currentSSID) {
        Write-Log "No Wifi Connection Detected! Reconnecting to '$correctSSID"
        
        # Reconnect to correct SSID (profile must exist)
        netsh wlan connect name="$correctSSID"
        Write-Log "Attempting to reconnect to '$correctSSID'..."

        Start-Sleep -Seconds $waitBeforeReconnectSeconds

        Write-Log "Now Connected to '$(Get-CurrentSSID)'"

    }
    elseif ($currentSSID -ne $correctSSID) {
        Write-Log "Connected to wrong network: '$currentSSID'. Expected: '$correctSSID'."
    
        # Disconnect
        netsh wlan disconnect
        Write-Log "Disconnected from '$currentSSID'."

        # Wait before reconnecting
        Start-Sleep -Seconds 3

        # Reconnect to correct SSID (profile must exist)
        netsh wlan connect name="$correctSSID"
        Write-Log "Attempting to reconnect to '$correctSSID'..."

        Start-Sleep -Second 3

        Write-Log "Now Connected to '$(Get-CurrentSSID)'"

    }
    else {
        Write-Log "Already connected to the correct network: '$correctSSID'."
    }
}



try {
    Compare-Elevation

    New-Log

    # Get current SSID
    $currentSSID = Get-CurrentSSID

    # Compare and take action
    Compare-Network
}
catch {
    Write-Log "UNHANDLED EXCEPTION: $_"
}
finally {
    Close-Triage
}