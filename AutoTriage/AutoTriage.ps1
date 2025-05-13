# AutoTriage.ps1 
# Contributors: Chris McLernon
# Description: Automates JMC triage for a POS register on Windows 11

# Variables
$issueTyping = @("Promos Not Working")
$currentDir = Get-Location
$scriptState = @{
    IncidentCaptured = $false
    IssueSelected    = $false
    NetworkSet       = $false
}
$logDate = Get-Date -Format "ddMMyyyy"
$logDir = Join-Path $currentDirectory "Transcript_Logs"
$logFile = Join-Path $logDir "tsLog_${logDate}.txt"

# Ensure base log folder exists
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Placeholder vars until inputs are captured
$incidentNumber = "INC000000"
$triageDir = Join-Path $currentDirectory "Triage_Report\triageReport_$incidentNumber"
$xccOutputFile = "XCCPEM_$incidentNumber.txt"
$xccOutputFilePath = Join-Path $triageDir $xccOutputFile
$stackTraceFile = "stacktrace_$incidentNumber.txt"
$stackTraceFilePath = Join-Path $triageDir $stackTraceFile
$PromoLog = "promoFiles_$incidentNumber.txt"
$promoLogPath = Join-Path $triageDir $PromoLog

# Relaunch script as admin if not already elevated
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Re-launching script with Administrator privileges..."

    $scriptPath = $PSCommandPath
    Start-Process "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-Command", "& {cd '$currentDirectory'; & '$scriptPath'}" -Verb RunAs
    exit 1
}
