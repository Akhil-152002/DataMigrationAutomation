#===========================================================
# ApprovalCheck.ps1
# Checks Approval and Cutover Window
#===========================================================

# Load Common Functions
. "$PSScriptRoot\Common.ps1"

try {

    Initialize-Log

    Write-Log "==================================================" "INFO"
    Write-Log "Approval Check Started" "INFO"
    Write-Log "==================================================" "INFO"

    #-------------------------------------------------------
    # Load Request
    #-------------------------------------------------------

    $Request = Get-MigrationRequest

    #-------------------------------------------------------
    # Verify Initial Copy
    #-------------------------------------------------------

    if ($Request.InitialCopyStatus -ne "Completed") {

        Write-Log "Initial Copy is not completed." "WARNING"
        return

    }

    #-------------------------------------------------------
    # Check Approval Status
    #-------------------------------------------------------

    if ($Request.ApprovalStatus -ne "Approved") {

        Write-Log "Approval is still Pending." "INFO"
        Write-Host ""
        Write-Host "Waiting for Business Approval..."
        Write-Host ""

        return

    }

    Write-Log "Business Approval Received." "SUCCESS"

    #-------------------------------------------------------
    # Check Cutover Window
    #-------------------------------------------------------

    Write-Log "Checking Cutover Window..."

    if (!(Test-CutoverWindow -Request $Request)) {

        Write-Log "Current time is outside the cutover window." "WARNING"

        Write-Host ""
        Write-Host "Cutover Window has not started."
        Write-Host ""

        return

    }

    Write-Log "Cutover Window is Active." "SUCCESS"

    #-------------------------------------------------------
    # Update Request
    #-------------------------------------------------------

    $Request.MigrationStatus = "Cutover Started"

    Save-MigrationRequest $Request

    #-------------------------------------------------------
    # Execute Final Copy
    #-------------------------------------------------------

    Write-Log "Starting Final Copy..." "INFO"

    & "$PSScriptRoot\FinalCopy.ps1"

    if ($LASTEXITCODE -ne 0) {

        throw "Final Copy failed."

    }

    Write-Log "Final Copy Completed." "SUCCESS"

    #-------------------------------------------------------
    # Execute Cutover
    #-------------------------------------------------------

    Write-Log "Starting Cutover..." "INFO"

    & "$PSScriptRoot\Cutover.ps1"

    if ($LASTEXITCODE -ne 0) {

        throw "Cutover failed."

    }

    Write-Log "Cutover Completed." "SUCCESS"

    Write-Host ""
    Write-Host "Migration Completed Successfully." -ForegroundColor Green
    Write-Host ""

}
catch {

    Write-Log $_.Exception.Message "ERROR"

    $Request = Get-MigrationRequest

    $Request.MigrationStatus = "Cutover Failed"

    Save-MigrationRequest $Request

    throw

}