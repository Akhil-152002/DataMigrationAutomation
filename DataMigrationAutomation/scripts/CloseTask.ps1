#===========================================================
# CloseTask.ps1
# Closes Migration Task
#===========================================================

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Closing Migration Task" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Load Request
    #-------------------------------------------------------

    $Request = Get-MigrationRequest

    #-------------------------------------------------------
    # Verify Migration Completed
    #-------------------------------------------------------

    if ($Request.MigrationStatus -ne "Migration Completed") {

        throw "Migration has not completed successfully."

    }

    #-------------------------------------------------------
    # Update Request
    #-------------------------------------------------------

    $Request.TaskStatus = "Closed Complete"

    $Request.ClosureRemarks = "Migration completed successfully. Initial Copy, Final Copy and Cutover completed successfully."

    $Request.ClosedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Save-MigrationRequest $Request

    Write-Log "Migration Request Updated." "SUCCESS"

    #-------------------------------------------------------
    # Send Closure Email
    #-------------------------------------------------------

    $Template = Get-EmailTemplate "Closure.html"

    $Body = New-EmailBody `
        -Template $Template `
        -Request $Request

    Send-Email `
        -To $Request.Email `
        -Subject "Migration Request Closed - $($Request.RequestID)" `
        -Body $Body

    Write-Log "Closure Email Sent." "SUCCESS"

    #-------------------------------------------------------
    # Display Summary
    #-------------------------------------------------------

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "Migration Task Closed Successfully"
    Write-Host "=============================================="
    Write-Host ""
    Write-Host "Request ID : $($Request.RequestID)"
    Write-Host "Task Status: $($Request.TaskStatus)"
    Write-Host "Closed On  : $($Request.ClosedDate)"
    Write-Host ""

    Write-Log "Migration Task Closed Successfully." "SUCCESS"

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    $Request = Get-MigrationRequest

    $Request.TaskStatus = "Closure Failed"

    Save-MigrationRequest $Request

    $Body = @"
<html>
<body>

<h2>Migration Task Closure Failed</h2>

<p>The migration completed, but the task could not be closed automatically.</p>

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

<p>Please close the task manually.</p>

</body>
</html>
"@

    Send-Email `
        -To $Request.Email `
        -Subject "Migration Task Closure Failed - $($Request.RequestID)" `
        -Body $Body

    throw

}
#-----------------------------------------------------------
# Archive Source Folder
#-----------------------------------------------------------

Write-Log "Starting archive process..."

$Request = Get-MigrationRequest

# Source folder
$SourceFolder = $Request.Source

# Parent directory of the source folder
$ParentFolder = Split-Path `
    -Path $SourceFolder `
    -Parent

# Archive folder (REQ_SCTASK)
$ArchiveFolder = Join-Path `
    -Path $ParentFolder `
    -ChildPath "$($Request.RequestID)_$($Request.SCTASK)"

# Create archive folder if it doesn't exist
if (!(Test-Path $ArchiveFolder)) {

    New-Item `
        -ItemType Directory `
        -Path $ArchiveFolder `
        -Force | Out-Null

    Write-Log "Archive folder created: $ArchiveFolder"

}

# Move Source folder into archive folder
if (Test-Path $SourceFolder) {

    Move-Item `
        -Path $SourceFolder `
        -Destination $ArchiveFolder `
        -Force

    Write-Log "Source folder archived successfully."

    $Request.ArchiveCreated = $true

}
else {

    Write-Log "Source folder not found." "WARNING"

    $Request.ArchiveCreated = $false

}

# Hide the archive folder
$ArchiveItem = Get-Item $ArchiveFolder

$ArchiveItem.Attributes = `
    $ArchiveItem.Attributes -bor [System.IO.FileAttributes]::Hidden

Write-Log "Archive folder marked as Hidden."

# Save request
Save-MigrationRequest $Request

Write-Log "Archive process completed successfully." "SUCCESS"