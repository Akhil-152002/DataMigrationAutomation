#===========================================================
# GenerateReport.ps1
# Generates Migration Report
#===========================================================

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Generating Migration Report" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Load Configuration
    #-------------------------------------------------------

    $Config  = Get-MigrationConfig
    $Request = Get-MigrationRequest

    #-------------------------------------------------------
    # Ensure Report Directory Exists
    #-------------------------------------------------------

    if (!(Test-Path $Config.ReportPath)) {

        New-Item `
            -ItemType Directory `
            -Path $Config.ReportPath `
            -Force | Out-Null

    }

    #-------------------------------------------------------
    # Report File Names
    #-------------------------------------------------------

    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $HtmlReport = Join-Path `
        $Config.ReportPath `
        "$($Request.RequestID)_MigrationReport_$Date.html"

    $CsvReport = Join-Path `
        $Config.ReportPath `
        "$($Request.RequestID)_MigrationReport_$Date.csv"

    #-------------------------------------------------------
    # Create HTML Report
    #-------------------------------------------------------

    $Html = @"
<html>

<head>

<title>Migration Report</title>

<style>

body{

font-family:Calibri;
font-size:14px;

}

table{

border-collapse:collapse;
width:80%;

}

th{

background:#4472C4;
color:white;
padding:8px;
border:1px solid black;

}

td{

padding:8px;
border:1px solid black;

}

</style>

</head>

<body>

<h2>Windows File Share Migration Report</h2>

<table>

<tr><th>Property</th><th>Value</th></tr>

<tr><td>Request ID</td><td>$($Request.RequestID)</td></tr>

<tr><td>RITM</td><td>$($Request.RITM)</td></tr>

<tr><td>SCTASK</td><td>$($Request.SCTASK)</td></tr>

<tr><td>Business Owner</td><td>$($Request.BusinessOwner)</td></tr>

<tr><td>Email</td><td>$($Request.Email)</td></tr>

<tr><td>Source</td><td>$($Request.Source)</td></tr>

<tr><td>Destination</td><td>$($Request.Destination)</td></tr>

<tr><td>Validation Status</td><td>$($Request.ValidationStatus)</td></tr>

<tr><td>Initial Copy</td><td>$($Request.InitialCopyStatus)</td></tr>

<tr><td>Approval Status</td><td>$($Request.ApprovalStatus)</td></tr>

<tr><td>Final Copy</td><td>$($Request.FinalCopyStatus)</td></tr>

<tr><td>Cutover</td><td>$($Request.CutoverStatus)</td></tr>

<tr><td>Rollback</td><td>$($Request.RollbackStatus)</td></tr>

<tr><td>Migration Status</td><td>$($Request.MigrationStatus)</td></tr>

<tr><td>Generated On</td><td>$(Get-Date)</td></tr>

</table>

</body>

</html>
"@

    $Html | Out-File `
        -FilePath $HtmlReport `
        -Encoding UTF8

    Write-Log "HTML Report Generated." "SUCCESS"

    #-------------------------------------------------------
    # Create CSV Report
    #-------------------------------------------------------

    $Report = [PSCustomObject]@{

        RequestID        = $Request.RequestID
        RITM             = $Request.RITM
        SCTASK           = $Request.SCTASK
        BusinessOwner    = $Request.BusinessOwner
        Email            = $Request.Email
        Source           = $Request.Source
        Destination      = $Request.Destination
        ValidationStatus = $Request.ValidationStatus
        InitialCopy      = $Request.InitialCopyStatus
        ApprovalStatus   = $Request.ApprovalStatus
        FinalCopy        = $Request.FinalCopyStatus
        Cutover          = $Request.CutoverStatus
        Rollback         = $Request.RollbackStatus
        MigrationStatus  = $Request.MigrationStatus
        ReportGenerated  = Get-Date

    }

    $Report | Export-Csv `
        -Path $CsvReport `
        -NoTypeInformation

    Write-Log "CSV Report Generated." "SUCCESS"

    #-------------------------------------------------------
    # Update Request
    #-------------------------------------------------------

    $Request.ReportGenerated = $true

    Save-MigrationRequest $Request

    Write-Log "Migration Request Updated." "SUCCESS"

    Write-Host ""
    Write-Host "===================================" -ForegroundColor Green
    Write-Host "Migration Report Generated"
    Write-Host "==================================="
    Write-Host ""
    Write-Host "HTML Report : $HtmlReport"
    Write-Host "CSV Report  : $CsvReport"
    Write-Host ""

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    throw

}