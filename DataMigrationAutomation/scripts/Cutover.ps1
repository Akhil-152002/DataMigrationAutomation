#===========================================================
# Cutover.ps1
# Performs Migration Cutover
#===========================================================

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Cutover Started" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Load Request
    #-------------------------------------------------------

    $Request = Get-MigrationRequest

    #-------------------------------------------------------
    # Verify Final Copy
    #-------------------------------------------------------

    if ($Request.FinalCopyStatus -ne "Completed") {

        throw "Final Copy has not completed successfully."

    }

    #-------------------------------------------------------
    # Verify Cutover Window
    #-------------------------------------------------------

    if (!(Test-CutoverWindow -Request $Request)) {

        throw "Current time is outside the configured cutover window."

    }

    Write-Log "Cutover Window Verified." "SUCCESS"

    #-------------------------------------------------------
    # Verify Destination
    #-------------------------------------------------------

    if (!(Test-Path $Request.Destination)) {

        throw "Destination path is not accessible."

    }

    Write-Log "Destination Share Verified." "SUCCESS"

    #-------------------------------------------------------
    # Simulate Source Lock
    #-------------------------------------------------------

    Write-Log "Locking Source Share (Simulation)." "INFO"

    # Real Environment:
    # Revoke user permissions
    # Make share read-only
    # Disable SMB Share

    Start-Sleep -Seconds 2

    Write-Log "Source Share Locked." "SUCCESS"

    #-------------------------------------------------------
    # Simulate DFS Update
    #-------------------------------------------------------

    Write-Log "Updating DFS Namespace (Simulation)." "INFO"

    # Real Environment:
    # Update DFS target
    # Point namespace to new share

    Start-Sleep -Seconds 2

    Write-Log "DFS Updated Successfully." "SUCCESS"

    #-------------------------------------------------------
    # Update Request
    #-------------------------------------------------------

    $Request.CutoverStatus = "Completed"
    $Request.CutoverCompleted = $true
    $Request.MigrationStatus = "Migration Completed"

    Save-MigrationRequest $Request

    Write-Log "Migration Status Updated." "SUCCESS"

    #-------------------------------------------------------
    # Generate Report
    #-------------------------------------------------------

    Write-Log "Generating Migration Report..." "INFO"

    & "$PSScriptRoot\GenerateReport.ps1"

    Write-Log "Migration Report Generated." "SUCCESS"

    #-------------------------------------------------------
    # Send Completion Email
    #-------------------------------------------------------

    $Template = Get-EmailTemplate "Completion.html"

    $Body = New-EmailBody `
        -Template $Template `
        -Request $Request
    Send-Email `
        -To $Request.Email `
        -Subject "Migration Completed Successfully - $($Request.RequestID)" `
        -Body $Body

    Write-Log "Completion Email Sent." "SUCCESS"

    #-------------------------------------------------------
    # Close Task
    #-------------------------------------------------------

    Write-Log "Closing Migration Task..." "INFO"

    & "$PSScriptRoot\CloseTask.ps1"

    Write-Log "Migration Task Closed." "SUCCESS"

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Migration Completed Successfully"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "Request ID : $($Request.RequestID)"
    Write-Host "Status     : Migration Completed"
    Write-Host ""

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    $Request = Get-MigrationRequest

    $Request.CutoverStatus = "Failed"
    $Request.MigrationStatus = "Cutover Failed"

    Save-MigrationRequest $Request

    $Body = @"
<html>
<body>

<h2>Migration Cutover Failed</h2>

<p>The migration could not be completed during the cutover window.</p>

<table border='1' cellpadding='5' cellspacing='0'>

<tr>
<td><b>Request ID</b></td>
<td>$($Request.RequestID)</td>
</tr>

<tr>
<td><b>Error</b></td>
<td>$($_.Exception.Message)</td>
</tr>

</table>

<p>Please review the logs and investigate the failure.</p>

</body>
</html>
"@

    Send-Email `
        -To $Request.Email `
        -Subject "Cutover Failed - $($Request.RequestID)" `
        -Body $Body

    throw

}