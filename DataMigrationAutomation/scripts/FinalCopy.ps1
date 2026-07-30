#===========================================================
# FinalCopy.ps1
# Performs Final Incremental Copy
#===========================================================

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Final Copy Started" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Load Configuration & Request
    #-------------------------------------------------------

    $Config = Get-MigrationConfig
    $Request = Get-MigrationRequest

    #-------------------------------------------------------
    # Verify Approval
    #-------------------------------------------------------

    if ($Request.ApprovalStatus -ne "Approved") {

        throw "Business approval not received."

    }

    #-------------------------------------------------------
    # Verify Paths
    #-------------------------------------------------------

    if (!(Test-Path $Request.Source)) {

        throw "Source path does not exist."

    }

    if (!(Test-Path $Request.Destination)) {

        throw "Destination path does not exist."

    }

    #-------------------------------------------------------
    # Start Final Copy
    #-------------------------------------------------------

    Write-Log "Running Final Robocopy..."

    $LogFile = Join-Path `
        $Config.LogPath `
        "$($Request.RequestID)_FinalCopy.log"

    # Incremental copy - copies only new/changed files
    $Options = "/E /XO /COPY:DAT /R:2 /W:2 /TEE /V /TS /FP /NP /LOG:`"$LogFile`""

    $Result = Invoke-MigrationCopy `
        -Source $Request.Source `
        -Destination $Request.Destination `
        -Options $Options

    #-------------------------------------------------------
    # Evaluate Robocopy Exit Code
    #-------------------------------------------------------

    if ($Result.ExitCode -gt 7) {

        throw "Robocopy failed with Exit Code $($Result.ExitCode)"

    }

    Write-Log "Final Copy Completed Successfully." "SUCCESS"

    #-------------------------------------------------------
    # Update Request
    #-------------------------------------------------------

    $Request.FinalCopyStatus = "Completed"
    $Request.MigrationStatus = "Final Copy Completed"

    Save-MigrationRequest $Request

    #-------------------------------------------------------
    # Send Email
    #-------------------------------------------------------

    $Body = @"
<html>
<body>

<h2>Final Copy Completed</h2>

<p>The final synchronization has completed successfully.</p>

<table border='1' cellpadding='5' cellspacing='0'>

<tr>
<td><b>Request ID</b></td>
<td>$($Request.RequestID)</td>
</tr>

<tr>
<td><b>Source</b></td>
<td>$($Request.Source)</td>
</tr>

<tr>
<td><b>Destination</b></td>
<td>$($Request.Destination)</td>
</tr>

<tr>
<td><b>Status</b></td>
<td>Final Copy Completed</td>
</tr>

</table>

<br>

<p>The migration is now ready for cutover.</p>

</body>
</html>
"@

    Send-Email `
        -To $Request.Email `
        -Subject "Final Copy Completed - $($Request.RequestID)" `
        -Body $Body

    Write-Log "Final Copy Email Sent." "SUCCESS"

    Write-Host ""
    Write-Host "Final Copy Completed Successfully." -ForegroundColor Green
    Write-Host ""

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    $Request = Get-MigrationRequest

    $Request.FinalCopyStatus = "Failed"
    $Request.MigrationStatus = "Final Copy Failed"

    Save-MigrationRequest $Request

    $Body = @"
<html>
<body>

<h2>Final Copy Failed</h2>

<p>The final synchronization could not be completed.</p>

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

</body>
</html>
"@

    Send-Email `
        -To $Request.Email `
        -Subject "Final Copy Failed - $($Request.RequestID)" `
        -Body $Body

    Write-Log "Starting Rollback..." "WARNING"

    & "$PSScriptRoot\Rollback.ps1"

    throw

}