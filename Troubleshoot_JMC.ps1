# Troubleshoot_JMC.ps1
# Description: Automates JMC & XCCPEM triage for a POS register on Windows 11
# Logging Enabled: All output and errors go to troubleshoot_log.txt

$logDate = Get-Date -Format "ddMMyyyy"
$logFile = "troubleshoot_log_${logDate}.txt"
Start-Transcript -Path $logFile -Append

function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "[dd-MM-yyyy | HH:mm:ss]"
    Write-Host "$timestamp $Message"
}

try {
    # Step 1: Get Incident Number
    $incidentNumber = Read-Host "Enter Incident Number"
    if ([string]::IsNullOrWhiteSpace($incidentNumber)) {
        Write-Log "ERROR: Incident number is required. Aborting."
        pause; exit 1
    }

    Write-Log "Using Incident ID: $incidentNumber"

    # Step 2: Locate JMC Process (java.exe with highest memory)
    Write-Log "Scanning for java.exe processes..."
    $javaProcess = Get-Process java -ErrorAction SilentlyContinue | Sort-Object -Property WorkingSet64 -Descending | Select-Object -First 1
    if (-not $javaProcess) {
        Write-Log "ERROR: No java.exe process found. Ensure JMC is running."
        pause; exit 1
    }

    $jmcpid = $javaProcess.Id
    Write-Log "Targeting java.exe PID: $jmcpid (Memory: $([math]::Round($javaProcess.WorkingSet64 / 1MB, 2)) MB)"

    # Run jmap and jstack
    Push-Location "C:\Program Files\Java\jdk-17\bin"
    $jmapDumpFile = "heapdump_${incidentNumber}.hprof"
    $stackTraceFile = "stack_${incidentNumber}.txt"

    Write-Log "Generating heap dump..."
    Start-Process .\jmap.exe -ArgumentList "-dump:live,format=b,file=$jmapDumpFile $jmcpid" -Wait -NoNewWindow
    Write-Log "Generating stack trace..."
    Start-Process .\jstack.exe -ArgumentList "$jmcpid" -RedirectStandardOutput "$stackTraceFile" -Wait -NoNewWindow
    Pop-Location

    # Step 3: Check XCCPEM Service Status & Grab Log
    $serviceName = "XCCPEM"
    $logDir = "\\bbwres2843p02\c$\XCC\logPEM"
    $xccOutputFile = "XCCPEM_${incidentNumber}.txt"

    Write-Log "Checking status of service: $serviceName"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if (-not $service) {
        Write-Log "ERROR: Service '$serviceName' not found. Skipping service check."
    }
    else {
        Write-Log "Service status: $($service.Status)"
    
        if ($service.Status -eq 'Stopped') {
            try {
                Write-Log "Attempting to start '$serviceName'..."
                Start-Service -Name $serviceName
                Start-Sleep -Seconds 5
                Write-Log "Service '$serviceName' started successfully."
            }
            catch {
                Write-Log "ERROR: Failed to start service '$serviceName': $_"
            }
        }
        else {
            Write-Log "Service '$serviceName' is already running."
        }
    }

    Write-Log "Accessing XCCPEM logs from: $logDir"
    $latestLog = Get-ChildItem $logDir -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $latestLog) {
        Write-Log "ERROR: No log files found in $logDir"
        pause; exit 1
    }

    Write-Log "Found latest log: $($latestLog.Name)"
    $tailLines = Get-Content $latestLog.FullName | Select-Object -Last 3
    $tailLines | Out-File $xccOutputFile -Encoding UTF8


    # Step 4: Package Results
    $logsDir = "logs_${incidentNumber}"
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

    Copy-Item $stackTraceFile -Destination $logsDir
    Copy-Item $xccOutputFile -Destination $logsDir

    $zipFile = "${logsDir}.zip"
    Compress-Archive -Path "$logsDir\*" -DestinationPath $zipFile -Force
    Write-Log "Created archive: $zipFile"

    # Step 5: Display & Open
    Write-Log "Last 3 lines of XCCPEM log"
    $tailLines | ForEach-Object { Write-Host $_ }

    Write-Log "Opening folder: $logsDir"
    Start-Process "$logsDir"

    Write-Log "Triage complete. Output saved to $zipFile"
}
catch {
    Write-Log "UNHANDLED ERROR: $_"
}
finally {
    Stop-Transcript
    Write-Host "`nPress any key to close..."
    [void][System.Console]::ReadKey($true)
}