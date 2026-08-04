#===========================================================
# ReminderJob.ps1
# Sends Reminder Emails Until Approval
#===========================================================

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Reminder Job Started" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Load Configuration & Request
    #-------------------------------------------------------

    $Config = Get-MigrationConfig
    $Request = Get-MigrationRequest

    #-------------------------------------------------------
    # Initial Copy Must Be Completed
    #-------------------------------------------------------

    if ($Request.InitialCopyStatus -ne "Completed") {

        Write-Log "Initial Copy is not completed. Reminder skipped." "INFO"
        return

    }

    #-------------------------------------------------------
    # Stop if Approved
    #-------------------------------------------------------

    if ($Request.ApprovalStatus -eq "Approved") {

        Write-Log "Business Owner already approved. No reminder required." "SUCCESS"
        return

    }

    #-------------------------------------------------------
    # Maximum Follow Ups
    #-------------------------------------------------------

    if ($Request.FollowUpCount -ge $Config.MaximumFollowUps) {

        Write-Log "Maximum reminder count reached." "WARNING"
        return

    }

    #-------------------------------------------------------
    # Check Reminder Date
    #-------------------------------------------------------

    $Today = Get-Date

    if (![string]::IsNullOrWhiteSpace($Request.NextReminderDate)) {

        $ReminderDate = Get-Date $Request.NextReminderDate

        if ($Today -lt $ReminderDate) {

            Write-Log "Next reminder date has not arrived." "INFO"
            return

        }

    }

    #-------------------------------------------------------
    # Select Email Template
    #-------------------------------------------------------

    switch ($Request.FollowUpCount) {

        0 { $Template = "Reminder1.html" }

        1 { $Template = "Reminder2.html" }

        default { $Template = "FinalReminder.html" }

    }

    #-------------------------------------------------------
    # Build Email
    #-------------------------------------------------------

    $Template = Get-EmailTemplate "Closure.html"

    $Body = New-EmailBody `
        -Template $Template `
        -Request $Request

    Send-Email `
        -To $Request.Email `
        -Subject "Reminder: Business Validation Pending - $($Request.RequestID)" `
        -Body $Body

    Write-Log "Reminder Email Sent." "SUCCESS"

    #-------------------------------------------------------
    # Update Request
    #-------------------------------------------------------

    $Request.FollowUpCount++

    $Request.LastEmailSent = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $Request.NextReminderDate = (Get-Date).AddDays($Config.ReminderIntervalDays).ToString("yyyy-MM-dd")

    Save-MigrationRequest $Request

    Write-Log "Reminder information updated." "SUCCESS"

    Write-Host ""
    Write-Host "Reminder Email Sent Successfully." -ForegroundColor Green
    Write-Host ""

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    throw

}