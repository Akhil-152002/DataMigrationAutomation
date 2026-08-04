#===========================================================
# InitialCopy.ps1
# Performs Initial Data Copy
#===========================================================

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Initial Copy Started" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Load Configuration
    #-------------------------------------------------------

    $Config = Get-MigrationConfig
    $Request = Get-MigrationRequest

    #-------------------------------------------------------
    # Ensure Validation Completed
    #-------------------------------------------------------

    if ($Request.ValidationStatus -ne "Completed") {

        throw "Validation has not completed successfully."

    }

    #-------------------------------------------------------
    # Verify Source Path
    #-------------------------------------------------------

    if (!(Test-Path $Request.Source)) {

        throw "Source path not found: $($Request.Source)"

    }

    #-------------------------------------------------------
    # Verify Destination Path
    #-------------------------------------------------------

    if (!(Test-Path $Request.Destination)) {

        throw "Destination path not found: $($Request.Destination)"

    }

    #-------------------------------------------------------
    # Start Initial Copy
    #-------------------------------------------------------

    Write-Log "Starting Robocopy Initial Copy..."

    $LogFile = Join-Path `
        $Config.LogPath `
        "$($Request.RequestID)_InitialCopy.log"

    $RobocopyOptions = "$($Config.RobocopyOptions) /LOG:`"$LogFile`""

    Invoke-MigrationCopy `
        -Source $Request.Source `
        -Destination $Request.Destination `
        -Options $RobocopyOptions

    Write-Log "Initial Copy Completed Successfully." "SUCCESS"

    #-------------------------------------------------------
    # Update Request JSON
    #-------------------------------------------------------

    $Request.InitialCopyStatus = "Completed"
    $Request.MigrationStatus = "Initial Copy Completed"
    $Request.LastEmailSent = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $Request.NextReminderDate = (Get-Date).AddDays(2).ToString("yyyy-MM-dd")

    Save-MigrationRequest $Request

    #-------------------------------------------------------
    # Send Initial Copy Email
    #-------------------------------------------------------

    $Template = Get-EmailTemplate "InitialCopy.html"
    $Body = New-EmailBody `
        -Template $Template `
        -Request $Request

    Send-Email `
        -To $Request.Email `
        -Subject "Initial Data Copy Completed - $($Request.RequestID)" `
        -Body $Body

    Write-Log "Initial Copy Email Sent." "SUCCESS"

    #-------------------------------------------------------
    # Display Summary
    #-------------------------------------------------------

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "Initial Copy Completed Successfully"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Request ID : $($Request.RequestID)"
    Write-Host "Source     : $($Request.Source)"
    Write-Host "Destination: $($Request.Destination)"
    Write-Host ""
    Write-Host "Business validation period has started."
    Write-Host "Reminder emails will be sent every 2 days."
    Write-Host ""

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    $Request = Get-MigrationRequest

    $Request.InitialCopyStatus = "Failed"
    $Request.MigrationStatus = "Initial Copy Failed"

    Save-MigrationRequest $Request

    $Body = @"
<html>
<body>

<h2>Initial Copy Failed</h2>

<p>The initial migration could not be completed.</p>

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
<td>Initial Copy Failed</td>
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
        -Subject "Initial Copy Failed - $($Request.RequestID)" `
        -Body $Body

    throw

}