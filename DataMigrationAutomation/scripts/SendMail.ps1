#==============================================================================
# SendMail.ps1
#==============================================================================

. "$PSScriptRoot\Common.ps1"

try
{
    $Request = Get-MigrationRequest
    $Config  = Get-MigrationConfig

    Initialize-Log $Request

    Write-Section "SEND EMAIL"

    Write-Log "Preparing approval email..."

    #-------------------------------------------------------------
    # Email Subject
    #-------------------------------------------------------------

    $Subject = "[$($Request.RequestID)] Initial Copy Completed - Approval Required"

    #-------------------------------------------------------------
    # Email Body
    #-------------------------------------------------------------

    $Body = @"
Hello $($Request.BusinessOwner),

The Initial Data Copy has completed successfully.

Request ID : $($Request.RequestID)

Source      : $($Request.Source)

Destination : $($Request.Destination)

Scheduled Cutover :

$($Request.ScheduledCutover)

Please review the migrated data.

Reply with APPROVED to continue with the Final Copy and Cutover.

Regards,

Windows File Share Migration Team
"@

    #-------------------------------------------------------------
    # Simulate Email
    #-------------------------------------------------------------

    Write-Log "To      : $($Request.Email)"
    Write-Log "Subject : $Subject"
    Write-Log ""
    Write-Log $Body

    #-------------------------------------------------------------
    # Update Request
    #-------------------------------------------------------------

    $Request.LastEmailSent = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $Request.NextReminderDate = (Get-Date).AddDays($Config.ReminderIntervalDays).ToString("yyyy-MM-dd")

    $Request.FollowUpCount = 0

    $Request.MigrationStatus = "Waiting For Approval"

    Save-MigrationRequest $Request

    Write-Log ""
    Write-Log "Approval email sent successfully."

}
catch
{
    Write-Log $_.Exception.Message
    exit 1
}