#===========================================================
# GetRequest.ps1
# Builds / Updates Migration Request from Pipeline Parameters
#===========================================================

param(

    [string]$RITM,
    [string]$SCTASK,
    [string]$BusinessReason,
    [string]$SourcePath,
    [string]$DestinationPath,
    [string]$MigrationDate,
    [string]$ValidationOwner,
    [string]$Requester,
    [string]$Email,
    [string]$BusinessUnit

)

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Starting Migration Request Processing" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Check for an existing in-progress request for this RITM
    #-------------------------------------------------------
    # If ServiceNow already ran a previous stage (e.g. InitialCopy)
    # for this same RITM, an existing record will be sitting in
    # C:\Migration\Requests\migration-request.json. We MUST preserve
    # its stage statuses (InitialCopyStatus, FinalCopyStatus, etc.)
    # instead of resetting them, or later stages (ApprovalCheck,
    # FinalCopy, Cutover) will immediately fail their prerequisite
    # checks.

    $Existing = Get-MigrationRequest

    if ($Existing -ne $null -and $Existing.RITM -eq $RITM) {

        Write-Log "Existing request found for $RITM - merging new parameters, preserving stage status." "INFO"

        $Request = $Existing

        $Request.SCTASK            = $SCTASK
        $Request.RequestedBy       = $Requester
        $Request.BusinessOwner      = $ValidationOwner
        $Request.BusinessUnit       = $BusinessUnit
        $Request.BusinessReason     = $BusinessReason
        $Request.Email             = $Email
        $Request.Source            = $SourcePath
        $Request.Destination       = $DestinationPath
        $Request.ScheduledCutover   = $MigrationDate
        $Request.CutoverWindowStart = $MigrationDate
        $Request.CutoverWindowEnd   = $MigrationDate

    }
    else {

        if ($Existing -ne $null) {

            Write-Log "Existing request is for a different RITM ($($Existing.RITM)). Starting a fresh record for $RITM." "WARNING"

        }
        else {

            Write-Log "No existing request found. Creating a new record." "INFO"

        }

        # NOTE: BusinessOwner is mapped from ValidationOwner (sys_id) since
        # the ServiceNow catalog form does not supply a separate
        # "business owner" field. Change this mapping if that's not correct.

        $Request = [PSCustomObject]@{

            RequestID           = $RITM
            RITM                = $RITM
            SCTASK               = $SCTASK
            RequestedBy          = $Requester
            BusinessOwner         = $ValidationOwner
            BusinessUnit          = $BusinessUnit
            BusinessReason        = $BusinessReason
            Email                = $Email

            Source               = $SourcePath
            Destination          = $DestinationPath

            MigrationType         = "Windows File Share"
            RequestedDate         = (Get-Date).ToString("yyyy-MM-dd")

            ScheduledCutover      = $MigrationDate
            CutoverWindowStart    = $MigrationDate
            CutoverWindowEnd      = $MigrationDate

            ApprovalStatus        = "Pending"
            ApprovalDate          = ""

            FollowUpCount         = 0
            LastEmailSent         = ""
            NextReminderDate      = ""

            MigrationStatus       = "In Progress"
            ValidationStatus      = ""
            InitialCopyStatus     = ""
            FinalCopyStatus       = ""
            CutoverStatus         = ""
            CutoverCompleted      = $false
            RollbackStatus        = "Not Started"

            ReportGenerated       = $false
            ArchiveCreated        = $false

            TaskStatus            = "In Progress"
            ClosureRemarks        = ""
            ClosedDate            = ""

            RunTimestamp          = Get-TimeStamp

        }

    }

    #-------------------------------------------------------
    # Validate Mandatory Fields
    #-------------------------------------------------------

    $MandatoryFields = @(
        "RequestID",
        "RITM",
        "SCTASK",
        "RequestedBy",
        "Email",
        "Source",
        "Destination",
        "ScheduledCutover"
    )

    foreach ($Field in $MandatoryFields) {

        $Value = $Request.$Field

        if ([string]::IsNullOrWhiteSpace($Value)) {

            throw "$Field is missing. Check that the pipeline parameter was passed in correctly from ServiceNow."

        }

    }

    #-------------------------------------------------------
    # Save Request
    #-------------------------------------------------------
    Save-MigrationRequest $Request

    #-------------------------------------------------------
    # Display Request Details
    #-------------------------------------------------------

    Write-Host ""
    Write-Host "========== Migration Request ==========" -ForegroundColor Cyan

    Write-Host "Request ID          : $($Request.RequestID)"
    Write-Host "RITM               : $($Request.RITM)"
    Write-Host "SCTASK             : $($Request.SCTASK)"
    Write-Host "Requested By       : $($Request.RequestedBy)"
    Write-Host "Business Owner     : $($Request.BusinessOwner)"
    Write-Host "Business Unit      : $($Request.BusinessUnit)"
    Write-Host "Business Reason    : $($Request.BusinessReason)"
    Write-Host "Email              : $($Request.Email)"
    Write-Host "Source             : $($Request.Source)"
    Write-Host "Destination        : $($Request.Destination)"
    Write-Host "Cutover Window     : $($Request.CutoverWindowStart)"
    Write-Host "                     To"
    Write-Host "                     $($Request.CutoverWindowEnd)"
    Write-Host "Approval Status    : $($Request.ApprovalStatus)"
    Write-Host "Migration Status   : $($Request.MigrationStatus)"

    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Log "Request Loaded Successfully." "SUCCESS"
    Write-Log "Request ID      : $($Request.RequestID)"
    Write-Log "Business Owner  : $($Request.BusinessOwner)"
    Write-Log "Source          : $($Request.Source)"
    Write-Log "Destination     : $($Request.Destination)"
    Write-Log "Approval Status : $($Request.ApprovalStatus)"
    Write-Log "Migration Status: $($Request.MigrationStatus)"

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    throw

}
