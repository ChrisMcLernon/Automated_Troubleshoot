# Autage.ps1 
# Contributors: Chris McLernon
# Description: Automates JMC triage for a POS register on Windows 11

# Variables
$issueTyping = @("Promos Not Working")
$currentDirectory = Get-Location
$logDate = Get-Date -Format "ddMMyyyy"
$scriptState = @{
    IncidentCaptured = $false
    IssueSelected    = $false
    NetworkSet       = $false
}

# Relaunch script as admin if not already elevated
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Re-launching script with Administrator privileges..."

    $scriptPath = $PSCommandPath
    Start-Process "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-Command", "& {cd '$currentDirectory'; & '$scriptPath'}" -Verb RunAs
    exit 1
}

function Set-PathsAndDirs {
    $script:logFolder = Join-Path $currentDirectory "Error_Logs"
    $script:logFile = Join-Path $logFolder "troubleshoot_log_${logDate}.txt"

    # Ensure base log folder exists
    if (-not (Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder | Out-Null
    }

    # Placeholder vars until inputs are captured
    $script:incidentNumber = "INC000000"
    $script:triageDir = Join-Path $currentDirectory "triage_$($script:incidentNumber)"
    $script:xccOutputFile = "XCCPEM_$($script:incidentNumber).txt"
    $script:stackTraceFile = "stack_$($script:incidentNumber).txt"
    $script:jmapDumpFile = "heapdump_$($script:incidentNumber).hprof"
    $script:promoLogPath = Join-Path $script:triageDir "promoFiles_$($script:incidentNumber).log"
}


function New-Log {
    $logFolder = "Error_Logs"
    if (-not (Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder | Out-Null
    }

    $logFile = Join-Path $logFolder "troubleshoot_log_${logDate}.txt"
    Start-Transcript -Path $logFile -Append
    $script:logFile = $logFile
}

function Add-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "[dd-MM-yyyy | HH:mm:ss]"
    Write-Host "$timestamp $Message"
}

function New-Input {
    # Get Incident Number
    while (-not $scriptState.IncidentCaptured) {
        $script:incidentNumber = (Read-Host "Enter Incident Number").ToUpper().Trim()

        if ([string]::IsNullOrWhiteSpace($incidentNumber)) {
            Add-Log "ERROR: Incident number is required. Please try again."
            continue
        }

        if ($incidentNumber -notmatch '^INC\d+$') {
            Add-Log "ERROR: Incident number must start with 'INC' followed by digits (e.g., INC123456)."
            continue
        }

        $scriptState.IncidentCaptured = $true
    }

    # Get Issue Type
    while (-not $scriptState.IssueSelected) {
        $issueTypeInt = 0
        $i = 1
        foreach ($type in $issueTyping) {
            Write-Host "$i : $type"
            $i++
        }

        $selection = Read-Host "Enter Issue Type (number)"
        if (-not [int]::TryParse($selection, [ref]$issueTypeInt)) {
            Add-Log "ERROR: Invalid input. Enter a numeric value corresponding to the issue type."
            continue
        }

        if ($issueTypeInt -lt 1 -or $issueTypeInt -gt $issueTyping.Count) {
            Add-Log "ERROR: Invalid selection. Choose a number between 1 and $($issueTyping.Count)."
            continue
        }

        $script:issueType = $issueTypeInt
        $scriptState.IssueSelected = $true
    }

    # Get Network Name
    while (-not $scriptState.NetworkSet) {
        $script:networkName = (Read-Host "Enter Network Name").ToUpper().Trim()

        if ([string]::IsNullOrWhiteSpace($networkName)) {
            Add-Log "ERROR: Network name is required. Please try again."
            continue
        }

        if ($networkName -notmatch '^BBW(?:TAB|RES|COS)\d{4}P\d{2}$') {
            Add-Log "ERROR: Incorrect format. Expected: BBW(TAB/RES/COS)(Store Number)P(Device Number)"
            Add-Log "Example: BBWCOS9999P99"
            continue
        }

        $scriptState.NetworkSet = $true
    }

    Add-Log "Using Incident ID: $incidentNumber for $($issueTyping[$issueType - 1])"
}

function Get-StackTrace {
    Add-Log "Scanning for java.exe processes..."

    $javaProcess = Get-Process java -ErrorAction SilentlyContinue | Sort-Object -Property WorkingSet64 -Descending | Select-Object -First 1

    if (-not $javaProcess) {
        Add-Log "ERROR: No java.exe process found. Ensure JMC is running."
        return
    }

    $jmcpid = $javaProcess.Id
    Add-Log "Targeting java.exe PID: $jmcpid (Memory: $([math]::Round($javaProcess.WorkingSet64 / 1MB, 2)) MB)"

    $jdkBinPath = "C:\Program Files\Java\jdk-17\bin"
    if (-not (Test-Path $jdkBinPath)) {
        Add-Log "ERROR: JDK path not found: $jdkBinPath"
        return
    }

    $script:jmapDumpFile = "heapdump_${incidentNumber}.hprof"
    $script:stackTraceFile = "stack_${incidentNumber}.txt"

    if (-not (Test-Path $stackTraceFile)) {
        Add-Log "WARNING: Stack trace file was not created: $stackTraceFile"
    }

    if (-not (Test-Path $jmapDumpFile)) {
        Add-Log "WARNING: Heap dump file was not created: $jmapDumpFile"
    }

    Push-Location $jdkBinPath
    try {
        Add-Log "Generating heap dump with jmap..."
        & .\jmap.exe "-dump:live,format=b,file=$jmapDumpFile" "$jmcpid" 2>&1 | ForEach-Object { Add-Log "$_" }

        Add-Log "Generating stack trace with jstack..."
        & .\jstack.exe "$jmcpid" > "$stackTraceFile" 2>&1

        Add-Log "Heap dump and stack trace completed."
    }
    catch {
        Add-Log "ERROR: Failed to execute jmap or jstack: $_"
    }
    finally {
        Pop-Location
    }
}

function Get-XCCLog {
    $serviceName = "XCCPEM"
    $logDir = "\\${networkName}\c$\XCC\logPEM"
    $script:xccOutputFile = "XCCPEM_${incidentNumber}.txt"

    Add-Log "Checking status of service: $serviceName"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if (-not $service) {
        Add-Log "ERROR: Service '$serviceName' not found. Skipping service check."
    }
    else {
        Add-Log "Service status: $($service.Status)"
        
        if ($service.Status -eq 'Stopped') {
            try {
                Add-Log "Attempting to start '$serviceName'..."
                Start-Service -Name $serviceName
                Start-Sleep -Seconds 5
                Add-Log "Service '$serviceName' started successfully."
            }
            catch {
                Add-Log "ERROR: Failed to start service '$serviceName': $_"
            }
        }
        else {
            Add-Log "Service '$serviceName' is already running."
        }
    }

    Add-Log "Attempting to access log directory: $logDir"

    if (-not (Test-Path $logDir)) {
        Add-Log "ERROR: Log directory not accessible: $logDir"
        return
    }

    $logFiles = Get-ChildItem -Path $logDir -Filter "*.txt" | Sort-Object LastWriteTime -Descending

    if (-not $logFiles) {
        Add-Log "ERROR: No .txt files found in $logDir"
        return
    }

    $latestLog = $logFiles[0].FullName
    Add-Log "Latest log identified: $latestLog"

    try {
        Copy-Item -Path $latestLog -Destination $xccOutputFile -Force
        Add-Log "Copied latest XCC log to local file: $xccOutputFile"
    }
    catch {
        Add-Log "ERROR: Failed to copy XCC log: $_"
    }
}

function Group-Logs {
    $triageDir = "triage_$incidentNumber"

    if (-not (Test-Path $triageDir)) {
        New-Item -ItemType Directory -Path $triageDir | Out-Null
        Add-Log "Created directory: $triageDir"
    }

    $logFiles = @($xccOutputFile, $stackTraceFile, $jmapDumpFile, $pingOutputFile, $eventLogsZip)

    foreach ($file in $logFiles) {
        if (Test-Path $file) {
            Move-Item -Path $file -Destination $triageDir -Force
            Add-Log "Moved $file to $triageDir"
        }
        else {
            Add-Log "WARNING: File not found, skipping: $file"
        }
    }
}

function Open-Triage {
    $triageDir = "triage_$incidentNumber"

    if (Test-Path $triageDir) {
        Add-Log "Opening triage folder: $triageDir"
        Start-Process explorer.exe $triageDir
    }
    else {
        Add-Log "ERROR: Triage folder not found: $triageDir"
    }
}

function Read-PromoFiles {
    $logDir = Join-Path -Path $PWD -ChildPath "triage_$incidentNumber"
    $fileName = "promoFiles_$incidentNumber.log"
    $promoLogPath = Join-Path $logDir $fileName

    if (-not (Test-Path $logDir)) {
        Add-Log "ERROR: Promo log directory not found: $logDir"
        return
    }

    if (-not (Test-Path $promoLogPath)) {
        Add-Log "WARNING: Promo log file not created: $promoLogPath"
    }

    Add-Log "Creating promo file inventory at: $promoLogPath"

    try {
        @(
            "Log started at $(Get-Date)",
            "Promo-related files and folders in XCCPREM directory:"
        ) | Set-Content -Path $promoLogPath -Encoding UTF8

        # This would need to be adjusted to the correct path if known:
        $promoDir = "\\$networkName\c$\XCCPREM"

        if (Test-Path $promoDir) {
            Get-ChildItem -Path $promoDir -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                Add-Content -Path $promoLogPath -Value $_.FullName
            }
            Add-Log "Promo file inventory complete."
        }
        else {
            Add-Log "WARNING: Promo directory not found: $promoDir"
        }

    }
    catch {
        Add-Log "ERROR: Could not create promo inventory: $_"
    }
}

function Debug-Promo {
    Add-Log "Starting Promo debug workflow..."
    Get-XCCLog
    Group-Logs
    Read-PromoFiles
}

function Initialize-Triage {
    switch ($issueType) {
        1 { Debug-Promo }
        default {
            Add-Log "ERROR: Unsupported issue type: $issueType"
            exit 1
        }
    }
}

function Close-Triage { 
    Stop-Transcript

    Rename-Item -Path .\Error_Logs\troubleshoot_log_$logDate.txt -NewName "Log_$incidentNumber" > $null

    Write-Host "`nPress any key to close..."
    [void][System.Console]::ReadKey($true)
}


try {
    Set-PathsAndDirs
    New-Log
    New-Input
    # Update paths after capturing incident number
    $script:triageDir = Join-Path $currentDirectory "triage_$incidentNumber"
    $script:xccOutputFile = "XCCPEM_$incidentNumber.txt"
    $script:stackTraceFile = "stack_$incidentNumber.txt"
    $script:jmapDumpFile = "heapdump_$incidentNumber.hprof"
    $script:promoLogPath = Join-Path $script:triageDir "promoFiles_$incidentNumber.log"


    Get-StackTrace
    Initialize-Triage
    Open-Triage
}
catch {
    Add-Log "UNHANDLED EXCEPTION: $_"
}
finally {
    Close-Triage
}

