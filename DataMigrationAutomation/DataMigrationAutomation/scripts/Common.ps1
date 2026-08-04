#===========================================================
# Common.ps1
# Common Utility Functions
#===========================================================

#-----------------------------------------------------------
# Load Migration Configuration
#-----------------------------------------------------------
function Get-MigrationConfig {

    $ConfigFile = Join-Path $PSScriptRoot "..\config\migration-config.json"

    return Get-Content $ConfigFile -Raw | ConvertFrom-Json

}

#-----------------------------------------------------------
# Load SMTP Configuration
#-----------------------------------------------------------
function Get-SMTPConfig {

    $SMTPFile = Join-Path $PSScriptRoot "..\config\smtp-config.json"

    return Get-Content $SMTPFile -Raw | ConvertFrom-Json

}

#-----------------------------------------------------------
# Request File Path (PERSISTENT - outside the git checkout)
#-----------------------------------------------------------
# IMPORTANT: this file must live outside the repo working
# directory. The pipeline's "checkout: self" step resets the
# working directory to match git on every run, so anything
# written inside the repo (like the old requesters/ folder)
# gets wiped between stages. This path comes from
# migration-config.json's "RequestPath" and defaults to
# C:\Migration\Requests if not set.
#-----------------------------------------------------------
function Get-RequestFilePath {

    $Config = Get-MigrationConfig

    $RequestPath = $Config.RequestPath

    if ([string]::IsNullOrWhiteSpace($RequestPath)) {

        $RequestPath = "C:\Migration\Requests"

    }

    if (!(Test-Path $RequestPath)) {

        New-Item `
            -ItemType Directory `
            -Path $RequestPath `
            -Force | Out-Null

    }

    return (Join-Path $RequestPath "migration-request.json")

}

#-----------------------------------------------------------
# Load Migration Request
#-----------------------------------------------------------
function Get-MigrationRequest {

    $RequestFile = Get-RequestFilePath

    if (!(Test-Path $RequestFile)) {

        return $null

    }

    return Get-Content $RequestFile -Raw | ConvertFrom-Json

}

#-----------------------------------------------------------
# Save Migration Request
#-----------------------------------------------------------
function Save-MigrationRequest {

    param($Request)

    $RequestFile = Get-RequestFilePath

    $Request | ConvertTo-Json -Depth 20 | Set-Content $RequestFile

}

#-----------------------------------------------------------
# Current Timestamp
#-----------------------------------------------------------
function Get-TimeStamp {

    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

}

#-----------------------------------------------------------
# Initialize Log
#-----------------------------------------------------------
function Initialize-Log {

    $Config = Get-MigrationConfig

    if (!(Test-Path $Config.LogPath)) {

        New-Item `
            -ItemType Directory `
            -Path $Config.LogPath `
            -Force | Out-Null

    }

    $Global:LogFile = Join-Path `
        $Config.LogPath `
        ("Migration_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

}

#-----------------------------------------------------------
# Logging
#-----------------------------------------------------------
function Write-Log {

    param(

        [string]$Message,

        [string]$Level = "INFO"

    )

    $Line = "$(Get-TimeStamp) [$Level] $Message"

    Write-Host $Line

    Add-Content `
        -Path $Global:LogFile `
        -Value $Line

}

#-----------------------------------------------------------
# Section Header (console + log)
#-----------------------------------------------------------
function Write-Section {

    param(

        [string]$Title

    )

    $Line = "===== $Title ====="

    Write-Host ""
    Write-Host $Line -ForegroundColor Cyan
    Write-Host ""

    if ($Global:LogFile) {

        Add-Content -Path $Global:LogFile -Value ""
        Add-Content -Path $Global:LogFile -Value $Line

    }

}

#-----------------------------------------------------------
# Check Folder
#-----------------------------------------------------------
function Test-RequiredPath {

    param([string]$Path)

    if (!(Test-Path $Path)) {

        throw "Path not found : $Path"

    }

}

#-----------------------------------------------------------
# Create Folder
#-----------------------------------------------------------
function New-Directory {

    param([string]$Path)

    if (!(Test-Path $Path)) {

        New-Item `
            -ItemType Directory `
            -Path $Path `
            -Force | Out-Null

    }

}

#-----------------------------------------------------------
# Hide Folder
#-----------------------------------------------------------
function New-HiddenFolder {

    param([string]$Path)

    if (Test-Path $Path) {

        (Get-Item $Path).Attributes = 'Hidden'

    }

}

#-----------------------------------------------------------
# Load HTML Template
#-----------------------------------------------------------
function Get-EmailTemplate {

    param(

        [string]$TemplateName

    )

    $Template = Join-Path `
        $PSScriptRoot `
        "..\templates\$TemplateName"

    return Get-Content `
        $Template `
        -Raw

}

#-----------------------------------------------------------
# Replace HTML Placeholders
#-----------------------------------------------------------
function New-EmailBody {

    param(

        [string]$Template,

        $Request

    )

    $Template = $Template.Replace("{{RequestID}}", [string]$Request.RequestID)
    $Template = $Template.Replace("{{RITM}}", [string]$Request.RITM)
    $Template = $Template.Replace("{{SCTASK}}", [string]$Request.SCTASK)
    $Template = $Template.Replace("{{RequestedBy}}", [string]$Request.RequestedBy)
    $Template = $Template.Replace("{{BusinessOwner}}", [string]$Request.BusinessOwner)
    $Template = $Template.Replace("{{Email}}", [string]$Request.Email)

    $Template = $Template.Replace("{{Source}}", $Request.Source)
    $Template = $Template.Replace("{{Destination}}", $Request.Destination)

    $Template = $Template.Replace("{{ScheduledCutover}}", $Request.ScheduledCutover)
    $Template = $Template.Replace("{{CutoverWindowStart}}", $Request.CutoverWindowStart)
    $Template = $Template.Replace("{{CutoverWindowEnd}}", $Request.CutoverWindowEnd)

    $Template = $Template.Replace("{{ValidationStatus}}", $Request.ValidationStatus)
    $Template = $Template.Replace("{{InitialCopyStatus}}", $Request.InitialCopyStatus)
    $Template = $Template.Replace("{{ApprovalStatus}}", $Request.ApprovalStatus)
    $Template = $Template.Replace("{{FinalCopyStatus}}", $Request.FinalCopyStatus)
    $Template = $Template.Replace("{{CutoverStatus}}", $Request.CutoverStatus)
    $Template = $Template.Replace("{{RollbackStatus}}", $Request.RollbackStatus)
    $Template = $Template.Replace("{{MigrationStatus}}", $Request.MigrationStatus)

    $Template = $Template.Replace("{{RunTimestamp}}", $Request.RunTimestamp)
    $Template = $Template.Replace("{{ClosedDate}}", $Request.ClosedDate)

    $Template = $Template.Replace("{{FailureReason}}", $Request.ClosureRemarks)

    return $Template

}

#-----------------------------------------------------------
# Gmail Email
#-----------------------------------------------------------
function Send-Email {

    param(

        [string]$To,

        [string]$Subject,

        [string]$Body,

        [string]$Attachment

    )

    try {

        $SMTP = Get-SMTPConfig

        $Password = ConvertTo-SecureString `
            $SMTP.Password `
            -AsPlainText `
            -Force

        $Credential = New-Object `
            System.Management.Automation.PSCredential(
                $SMTP.Username,
                $Password
            )

        $Mail = @{

            From       = $SMTP.SenderEmail
            To         = $To
            Subject    = $Subject
            Body       = $Body
            BodyAsHtml = $true
            SmtpServer = $SMTP.SMTPServer
            Port       = $SMTP.Port
            UseSsl     = $SMTP.UseSSL
            Credential = $Credential

        }

        if($Attachment){

            $Mail.Add("Attachments",$Attachment)

        }

        Send-MailMessage @Mail

        Write-Log "Email sent to $To" "SUCCESS"

    }
    catch{

        Write-Log $_.Exception.Message "ERROR"

        throw

    }

}

#-----------------------------------------------------------
# Robocopy Wrapper
#-----------------------------------------------------------
function Invoke-MigrationCopy {

    param(

        [string]$Source,

        [string]$Destination,

        [string]$Options

    )

    Write-Log "Source      : $Source"
    Write-Log "Destination : $Destination"
    Write-Log "Options     : $Options"

    $OptionList = $Options -split '\s+'

    & robocopy $Source $Destination @OptionList

    $ExitCode = $LASTEXITCODE

    Write-Log "Robocopy Exit Code : $ExitCode"

    if ($ExitCode -gt 7) {

        throw "Robocopy Failed ExitCode : $ExitCode"

    }

    Write-Log "Robocopy completed successfully." "SUCCESS"

    return [PSCustomObject]@{ ExitCode = $ExitCode }

}
#-----------------------------------------------------------
# Check Weekend Cutover Window
#-----------------------------------------------------------
function Test-CutoverWindow {

    param($Request)

    $Now = Get-Date

    $Start = Get-Date $Request.CutoverWindowStart

    $End = Get-Date $Request.CutoverWindowEnd

    if($Now -ge $Start -and $Now -le $End){

        return $true

    }

    return $false

}
