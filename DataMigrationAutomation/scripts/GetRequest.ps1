#===========================================================
# GetRequest.ps1
# Builds Migration Request from Azure DevOps Pipeline Parameters
# (Replaces the old "Mock ServiceNow" local JSON file read)
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

    #-------------------------------------------------------
    # Initialize Log
    #-------------------------------------------------------
    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Starting Migration Request Processing" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Build Request Object from Pipeline Parameters
    #-------------------------------------------------------
    # NOTE: BusinessOwner is mapped from ValidationOwner (sys_id) since
    # the ServiceNow catalog form does not currently supply a separate
    # "business owner" field. Change this mapping if that's not correct.

    $Request = [PSCustomObject]@{

        RequestID          = $RITM
        RITM               = $RITM
        SCTASK              = $SCTASK
        RequestedBy         = $Requester
        BusinessOwner        = $ValidationOwner
        BusinessUnit         = $BusinessUnit
        BusinessReason       = $BusinessReason
        Email               = $Email
        Source              = $SourcePath
        Destination         = $DestinationPath
        ScheduledCutover     = $MigrationDate
        CutoverWindowStart   = $MigrationDate
        CutoverWindowEnd     = $MigrationDate
        ApprovalStatus       = "Pending"
        ValidationStatus     = ""
        InitialCopyStatus    = ""
        FinalCopyStatus      = ""
        CutoverStatus        = ""
        RollbackStatus       = ""
        MigrationStatus      = "In Progress"
        RunTimestamp         = ""
        ClosedDate           = ""
        ClosureRemarks       = ""

    }

    #-------------------------------------------------------
    # Generate Run Timestamp
    #-------------------------------------------------------
    if ([string]::IsNullOrWhiteSpace($Request.RunTimestamp)) {

        $Request.RunTimestamp = Get-TimeStamp

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
    # Save Request (downstream stages read this file)
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

    #-------------------------------------------------------
    # Log Request Summary
    #-------------------------------------------------------

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
