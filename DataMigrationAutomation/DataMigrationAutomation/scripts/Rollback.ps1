#===========================================================
# Rollback.ps1
# Restores Migration After Failure
#===========================================================

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Rollback Started" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Load Configuration
    #-------------------------------------------------------

    $Config  = Get-MigrationConfig
    $Request = Get-MigrationRequest

    #-------------------------------------------------------
    # Check Rollback Configuration
    #-------------------------------------------------------

    if ($Config.EnableRollback -ne $true) {

        Write-Log "Rollback is disabled in configuration." "WARNING"
        return

    }

    #-------------------------------------------------------
    # Verify Source Path
    #-------------------------------------------------------

    if (!(Test-Path $Request.Source)) {

        throw "Source path not found: $($Request.Source)"

    }

    Write-Log "Source Path Verified." "SUCCESS"

    #-------------------------------------------------------
    # Verify Destination Path
    #-------------------------------------------------------

    if (!(Test-Path $Request.Destination)) {

        throw "Destination path not found: $($Request.Destination)"

    }

    Write-Log "Destination Path Verified." "SUCCESS"

    #-------------------------------------------------------
    # Simulate Rollback
    #-------------------------------------------------------

    Write-Log "Restoring original environment..." "INFO"

    # Real Environment Examples:
    #
    # Restore DFS Namespace
    # Restore SMB Share Permissions
    # Enable Source Share
    # Disable Destination Share
    # Restore ACLs
    #

    Start-Sleep -Seconds 3

    Write-Log "Environment Restored Successfully." "SUCCESS"

    #-------------------------------------------------------
    # Archive Logs
    #-------------------------------------------------------

    $ArchiveFolder = Join-Path `
        $Config.ArchivePath `
        $Request.RequestID

    if (!(Test-Path $ArchiveFolder)) {

        New-Item `
            -ItemType Directory `
            -Path $ArchiveFolder `
            -Force | Out-Null

    }

    Copy-Item `
        -Path "$($Config.LogPath)\*" `
        -Destination $ArchiveFolder `
        -Recurse `
        -Force

    Write-Log "Logs Archived Successfully." "SUCCESS"

    #-------------------------------------------------------
    # Update Request
    #-------------------------------------------------------

    $Request.RollbackStatus = "Completed"
    $Request.MigrationStatus = "Rolled Back"

    Save-MigrationRequest $Request

    Write-Log "Request Updated Successfully." "SUCCESS"

    #-------------------------------------------------------
    # Send Rollback Email
    #-------------------------------------------------------

    $Body = @"
<html>
<body>

<h2>Migration Rollback Completed</h2>

<p>The migration encountered an issue and has been rolled back successfully.</p>

<table border='1' cellpadding='5' cellspacing='0'>

<tr>
<td><b>Request ID</b></td>
<td>$($Request.RequestID)</td>
</tr>

<tr>
<td><b>Migration Status</b></td>
<td>Rolled Back</td>
</tr>

<tr>
<td><b>Rollback Status</b></td>
<td>Completed</td>
</tr>

</table>

<br>

<p>Please review the migration logs before scheduling another cutover.</p>

</body>
</html>
"@

    Send-Email `
        -To $Request.Email `
        -Subject "Migration Rolled Back - $($Request.RequestID)" `
        -Body $Body

    Write-Log "Rollback Email Sent." "SUCCESS"

    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "Rollback Completed Successfully"
    Write-Host "========================================="
    Write-Host ""

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    $Request = Get-MigrationRequest

    $Request.RollbackStatus = "Failed"
    $Request.MigrationStatus = "Rollback Failed"

    Save-MigrationRequest $Request

    $Body = @"
<html>
<body>

<h2>Rollback Failed</h2>

<p>The rollback process could not be completed.</p>

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

<p>Immediate investigation is required.</p>

</body>
</html>
"@

    Send-Email `
        -To $Request.Email `
        -Subject "Rollback Failed - $($Request.RequestID)" `
        -Body $Body

    throw

}