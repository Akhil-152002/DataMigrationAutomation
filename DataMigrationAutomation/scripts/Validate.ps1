#===========================================================
# Validate.ps1
# Validate Migration Request
#===========================================================

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Validation Started" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Load Migration Request
    #-------------------------------------------------------
    $Request = Get-MigrationRequest

    #-------------------------------------------------------
    # Validate Source Path
    #-------------------------------------------------------

    Write-Log "Validating Source Path..."

    if (!(Test-Path $Request.Source)) {

        $Request.ValidationStatus = "Failed"
        $Request.MigrationStatus = "Validation Failed"

        Save-MigrationRequest $Request

        $Body = @"
<html>
<body>

<h2>Migration Validation Failed</h2>

<p>The Source Path does not exist.</p>

<table border='1' cellpadding='5' cellspacing='0'>

<tr>
<td><b>Request ID</b></td>
<td>$($Request.RequestID)</td>
</tr>

<tr>
<td><b>Source Path</b></td>
<td>$($Request.Source)</td>
</tr>

<tr>
<td><b>Status</b></td>
<td>Validation Failed</td>
</tr>

</table>

<br>

<p>Please verify the source path and submit the migration again.</p>

</body>
</html>
"@

        Send-Email `
            -To $Request.Email `
            -Subject "Migration Validation Failed - Source Path Not Found" `
            -Body $Body

        throw "Source Path does not exist : $($Request.Source)"

    }

    Write-Log "Source Path Verified." "SUCCESS"

    #-------------------------------------------------------
    # Validate Destination Path
    #-------------------------------------------------------

    Write-Log "Validating Destination Path..."

    if (!(Test-Path $Request.Destination)) {

        $Request.ValidationStatus = "Failed"
        $Request.MigrationStatus = "Validation Failed"

        Save-MigrationRequest $Request

        $Body = @"
<html>
<body>

<h2>Migration Validation Failed</h2>

<p>The Destination Path does not exist.</p>

<table border='1' cellpadding='5' cellspacing='0'>

<tr>
<td><b>Request ID</b></td>
<td>$($Request.RequestID)</td>
</tr>

<tr>
<td><b>Destination Path</b></td>
<td>$($Request.Destination)</td>
</tr>

<tr>
<td><b>Status</b></td>
<td>Validation Failed</td>
</tr>

</table>

<br>

<p>Please create the destination folder before running the migration.</p>

</body>
</html>
"@

        Send-Email `
            -To $Request.Email `
            -Subject "Migration Validation Failed - Destination Path Not Found" `
            -Body $Body

        throw "Destination Path does not exist : $($Request.Destination)"

    }

    Write-Log "Destination Path Verified." "SUCCESS"

    #-------------------------------------------------------
    # Destination Folder Should Be Empty
    #-------------------------------------------------------

    Write-Log "Checking Destination Folder..."

    $Items = Get-ChildItem `
        -Path $Request.Destination `
        -Force

    if ($Items.Count -gt 0) {

        $Request.ValidationStatus = "Failed"
        $Request.MigrationStatus = "Validation Failed"

        Save-MigrationRequest $Request

        $Body = @"
<html>
<body>

<h2>Migration Validation Failed</h2>

<p>The destination folder is not empty.</p>

<table border='1' cellpadding='5' cellspacing='0'>

<tr>
<td><b>Request ID</b></td>
<td>$($Request.RequestID)</td>
</tr>

<tr>
<td><b>Destination</b></td>
<td>$($Request.Destination)</td>
</tr>

<tr>
<td><b>Status</b></td>
<td>Destination Folder Not Empty</td>
</tr>

</table>

<br>

<p>Please empty the destination folder and rerun the migration.</p>

</body>
</html>
"@

        Send-Email `
            -To $Request.Email `
            -Subject "Migration Validation Failed - Destination Folder Not Empty" `
            -Body $Body

        throw "Destination Folder is not empty."

    }

    Write-Log "Destination Folder is Empty." "SUCCESS"

    #-------------------------------------------------------
    # Validate Email
    #-------------------------------------------------------

    Write-Log "Validating Requester Email..."

    if ([string]::IsNullOrWhiteSpace($Request.Email)) {

        throw "Requester Email is missing."

    }

    Write-Log "Requester Email Verified." "SUCCESS"

    #-------------------------------------------------------
    # Validate Cutover Window
    #-------------------------------------------------------

    Write-Log "Validating Cutover Window..."

    if ([string]::IsNullOrWhiteSpace($Request.CutoverWindowStart)) {

        throw "Cutover Window Start is missing."

    }

    if ([string]::IsNullOrWhiteSpace($Request.CutoverWindowEnd)) {

        throw "Cutover Window End is missing."

    }

    Write-Log "Cutover Window Verified." "SUCCESS"

    #-------------------------------------------------------
    # Validation Successful
    #-------------------------------------------------------

    $Request.ValidationStatus = "Completed"
    $Request.MigrationStatus = "Validated"

    Save-MigrationRequest $Request

    Write-Log "Validation Completed Successfully." "SUCCESS"

    Write-Host ""
    Write-Host "Validation Completed Successfully." -ForegroundColor Green

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    throw

}