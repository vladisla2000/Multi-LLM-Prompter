cls
# ============================================================
# Multi-LLM Prompter - Run Review Helper
# Version: v0.1
# Purpose: Review one completed run folder after live/API test.
# PowerShell: 5.1 / ISE friendly
# ============================================================

# -----------------------------
# USER PARAMETERS - EDIT HERE
# -----------------------------

$OutputRoot = "C:\Temp\MultiLLMPrompter"
$RunFolder = ""   # Leave empty to review latest Run_* folder under $OutputRoot
$OpenMarkdownReport = $true
$ExportCsvReport = $true
$MinimumFinalAnswerChars = 300

# -----------------------------
# FUNCTIONS
# -----------------------------

function Write-Color {
    param(
        [string]$Text,
        [string]$Color = "White"
    )

    Write-Host $Text -ForegroundColor $Color
}

function Write-Header {
    param([string]$Text)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Add-Check {
    param(
        [string]$Area,
        [string]$Check,
        [string]$Status,
        [string]$Details
    )

    $script:Checks += [pscustomobject]@{
        Area    = $Area
        Check   = $Check
        Status  = $Status
        Details = $Details
    }
}

function Get-LatestRunFolder {
    param([string]$RootPath)

    if (-not (Test-Path -LiteralPath $RootPath)) {
        return $null
    }

    try {
        $Folders = @(Get-ChildItem -LiteralPath $RootPath -Directory -Filter "Run_*" -ErrorAction Stop | Sort-Object LastWriteTime -Descending)
    }
    catch {
        return $null
    }

    if ($Folders.Count -eq 0) {
        return $null
    }

    return $Folders[0].FullName
}

function Get-FileTextSafe {
    param([string]$Path)

    try {
        if (Test-Path -LiteralPath $Path) {
            return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop)
        }
        else {
            return $null
        }
    }
    catch {
        return $null
    }
}

function ConvertFrom-JsonSafe {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    try {
        return ($Text | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        return $null
    }
}

function Escape-MarkdownCell {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $Value = $Text.Replace("|", "\|")
    $Value = $Value.Replace("`r", " ")
    $Value = $Value.Replace("`n", " ")
    return $Value
}

# -----------------------------
# MAIN
# -----------------------------

Write-Header "Multi-LLM Prompter Run Review Helper v0.1"

$Checks = @()
$NowStamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ([string]::IsNullOrWhiteSpace($RunFolder)) {
    Write-Color ">>> RunFolder is empty. Searching latest Run_* under: $OutputRoot" "Yellow"
    $RunFolder = Get-LatestRunFolder -RootPath $OutputRoot
}

if ([string]::IsNullOrWhiteSpace($RunFolder)) {
    Write-Color "[ERROR] No run folder found." "Red"
    Write-Color "Set `$RunFolder manually or run Multi-LLM Prompter first." "Yellow"
    exit 1
}

if (-not (Test-Path -LiteralPath $RunFolder)) {
    Write-Color "[ERROR] Run folder does not exist: $RunFolder" "Red"
    exit 1
}

Write-Color "[INFO] Reviewing: $RunFolder" "Gray"

$RequiredFiles = @(
    [pscustomobject]@{ Name = "input_prompt.txt";          Area = "Files"; Critical = $true  },
    [pscustomobject]@{ Name = "router_decision.json";      Area = "Files"; Critical = $true  },
    [pscustomobject]@{ Name = "answers_raw.json";          Area = "Files"; Critical = $true  },
    [pscustomobject]@{ Name = "errors.json";               Area = "Files"; Critical = $false },
    [pscustomobject]@{ Name = "run_metrics.csv";           Area = "Files"; Critical = $true  },
    [pscustomobject]@{ Name = "judge_raw.json";            Area = "Files"; Critical = $true  },
    [pscustomobject]@{ Name = "judge_text.txt";            Area = "Files"; Critical = $true  },
    [pscustomobject]@{ Name = "judge_parsed.json";         Area = "Files"; Critical = $true  },
    [pscustomobject]@{ Name = "final_answer.md";           Area = "Files"; Critical = $true  },
    [pscustomobject]@{ Name = "console_transcript.txt";    Area = "Files"; Critical = $false }
)

foreach ($Item in $RequiredFiles) {
    $Path = Join-Path $RunFolder $Item.Name

    if (Test-Path -LiteralPath $Path) {
        Add-Check -Area $Item.Area -Check $Item.Name -Status "OK" -Details "Found"
    }
    else {
        if ($Item.Critical -eq $true) {
            Add-Check -Area $Item.Area -Check $Item.Name -Status "ERROR" -Details "Missing critical output file"
        }
        else {
            Add-Check -Area $Item.Area -Check $Item.Name -Status "WARN" -Details "Missing optional output file"
        }
    }
}

# Answer markdown files are conditional: simple prompts may run OpenAI only.
$AnswerAPath = Join-Path $RunFolder "answer_A_OpenAI.md"
$AnswerBPath = Join-Path $RunFolder "answer_B_Anthropic.md"

if (Test-Path -LiteralPath $AnswerAPath) {
    $AnswerAText = Get-FileTextSafe -Path $AnswerAPath
    if ($AnswerAText.Length -gt 50) {
        Add-Check -Area "Answers" -Check "answer_A_OpenAI.md" -Status "OK" -Details "Found, length $($AnswerAText.Length) chars"
    }
    else {
        Add-Check -Area "Answers" -Check "answer_A_OpenAI.md" -Status "WARN" -Details "Found but very short"
    }
}
else {
    Add-Check -Area "Answers" -Check "answer_A_OpenAI.md" -Status "WARN" -Details "Missing"
}

if (Test-Path -LiteralPath $AnswerBPath) {
    $AnswerBText = Get-FileTextSafe -Path $AnswerBPath
    if ($AnswerBText.Length -gt 50) {
        Add-Check -Area "Answers" -Check "answer_B_Anthropic.md" -Status "OK" -Details "Found, length $($AnswerBText.Length) chars"
    }
    else {
        Add-Check -Area "Answers" -Check "answer_B_Anthropic.md" -Status "WARN" -Details "Found but very short"
    }
}
else {
    Add-Check -Area "Answers" -Check "answer_B_Anthropic.md" -Status "WARN" -Details "Missing; OK only for simple/OpenAI-only route or failed Anthropic call"
}

# Judge markers.
$JudgeTextPath = Join-Path $RunFolder "judge_text.txt"
$JudgeText = Get-FileTextSafe -Path $JudgeTextPath

if ($null -ne $JudgeText) {
    if ($JudgeText.Contains("---JUDGE_JSON---")) {
        Add-Check -Area "Judge" -Check "JUDGE_JSON marker" -Status "OK" -Details "Marker exists"
    }
    else {
        Add-Check -Area "Judge" -Check "JUDGE_JSON marker" -Status "ERROR" -Details "Marker missing"
    }

    if ($JudgeText.Contains("---FINAL_ANSWER_MARKDOWN---")) {
        Add-Check -Area "Judge" -Check "FINAL_ANSWER_MARKDOWN marker" -Status "OK" -Details "Marker exists"
    }
    else {
        Add-Check -Area "Judge" -Check "FINAL_ANSWER_MARKDOWN marker" -Status "ERROR" -Details "Marker missing"
    }

    if ($JudgeText.Contains("---IMPROVED_PROMPT---")) {
        Add-Check -Area "Judge" -Check "IMPROVED_PROMPT marker" -Status "OK" -Details "Marker exists"
    }
    else {
        Add-Check -Area "Judge" -Check "IMPROVED_PROMPT marker" -Status "WARN" -Details "Marker missing"
    }
}
else {
    Add-Check -Area "Judge" -Check "judge_text.txt readable" -Status "ERROR" -Details "Cannot read judge_text.txt"
}

# Judge parsed JSON.
$JudgeParsedPath = Join-Path $RunFolder "judge_parsed.json"
$JudgeParsedText = Get-FileTextSafe -Path $JudgeParsedPath
$JudgeParsed = ConvertFrom-JsonSafe -Text $JudgeParsedText

if ($null -ne $JudgeParsed) {
    Add-Check -Area "Judge" -Check "judge_parsed.json parse" -Status "OK" -Details "JSON parsed"

    $JudgeMode = ""
    $BestAnswerId = ""
    $Confidence = ""

    if ($JudgeParsed.PSObject.Properties.Name -contains "mode") {
        $JudgeMode = [string]$JudgeParsed.mode
    }

    if ($JudgeParsed.PSObject.Properties.Name -contains "best_answer_id") {
        $BestAnswerId = [string]$JudgeParsed.best_answer_id
    }

    if ($JudgeParsed.PSObject.Properties.Name -contains "confidence") {
        $Confidence = [string]$JudgeParsed.confidence
    }

    Add-Check -Area "Judge" -Check "judge contract fields" -Status "OK" -Details "mode=$JudgeMode; best_answer_id=$BestAnswerId; confidence=$Confidence"
}
else {
    Add-Check -Area "Judge" -Check "judge_parsed.json parse" -Status "ERROR" -Details "Cannot parse JSON"
}

# Metrics.
$MetricsPath = Join-Path $RunFolder "run_metrics.csv"
if (Test-Path -LiteralPath $MetricsPath) {
    try {
        $Metrics = @(Import-Csv -LiteralPath $MetricsPath -ErrorAction Stop)
        Add-Check -Area "Metrics" -Check "run_metrics.csv parse" -Status "OK" -Details "Rows: $($Metrics.Count)"

        $FailedRows = @($Metrics | Where-Object { $_.Success -notmatch "True|true|1" })
        if ($FailedRows.Count -eq 0) {
            Add-Check -Area "Metrics" -Check "provider success" -Status "OK" -Details "No failed metric rows"
        }
        else {
            $Names = @($FailedRows | ForEach-Object { "$($_.Provider)/$($_.Model)" }) -join "; "
            Add-Check -Area "Metrics" -Check "provider success" -Status "WARN" -Details "Failed rows: $Names"
        }
    }
    catch {
        Add-Check -Area "Metrics" -Check "run_metrics.csv parse" -Status "ERROR" -Details $_.Exception.Message
    }
}
else {
    Add-Check -Area "Metrics" -Check "run_metrics.csv parse" -Status "ERROR" -Details "Missing file"
}

# Final answer.
$FinalPath = Join-Path $RunFolder "final_answer.md"
$FinalText = Get-FileTextSafe -Path $FinalPath

if ($null -ne $FinalText) {
    if ($FinalText.Length -ge $MinimumFinalAnswerChars) {
        Add-Check -Area "Final" -Check "final_answer.md length" -Status "OK" -Details "Length $($FinalText.Length) chars"
    }
    else {
        Add-Check -Area "Final" -Check "final_answer.md length" -Status "WARN" -Details "Short final answer: $($FinalText.Length) chars"
    }
}
else {
    Add-Check -Area "Final" -Check "final_answer.md readable" -Status "ERROR" -Details "Cannot read final_answer.md"
}

# Summary counts.
$ErrorCount = @($Checks | Where-Object { $_.Status -eq "ERROR" }).Count
$WarnCount = @($Checks | Where-Object { $_.Status -eq "WARN" }).Count
$OkCount = @($Checks | Where-Object { $_.Status -eq "OK" }).Count

if ($ErrorCount -eq 0 -and $WarnCount -eq 0) {
    $Overall = "PASS"
}
elseif ($ErrorCount -eq 0 -and $WarnCount -gt 0) {
    $Overall = "PASS_WITH_WARNINGS"
}
else {
    $Overall = "FAIL"
}

Write-Header "Review Result: $Overall"
Write-Color "OK: $OkCount   WARN: $WarnCount   ERROR: $ErrorCount" "White"
Write-Host ""

foreach ($Check in $Checks) {
    if ($Check.Status -eq "OK") {
        Write-Color "[OK]    $($Check.Area) - $($Check.Check): $($Check.Details)" "Green"
    }
    elseif ($Check.Status -eq "WARN") {
        Write-Color "[WARN]  $($Check.Area) - $($Check.Check): $($Check.Details)" "Yellow"
    }
    else {
        Write-Color "[ERROR] $($Check.Area) - $($Check.Check): $($Check.Details)" "Red"
    }
}

# Write reports.
$ReportPath = Join-Path $RunFolder ("run_review_" + $NowStamp + ".md")
$CsvPath = Join-Path $RunFolder ("run_review_" + $NowStamp + ".csv")

$ReportLines = @()
$ReportLines += "# Multi-LLM Prompter Run Review"
$ReportLines += ""
$ReportLines += "- Reviewed folder: `$RunFolder`"
$ReportLines += "- Review time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$ReportLines += "- Overall: **$Overall**"
$ReportLines += "- OK: $OkCount"
$ReportLines += "- WARN: $WarnCount"
$ReportLines += "- ERROR: $ErrorCount"
$ReportLines += ""
$ReportLines += "## Checks"
$ReportLines += ""
$ReportLines += "| Area | Check | Status | Details |"
$ReportLines += "|---|---|---|---|"

foreach ($Check in $Checks) {
    $ReportLines += "| $(Escape-MarkdownCell $Check.Area) | $(Escape-MarkdownCell $Check.Check) | $(Escape-MarkdownCell $Check.Status) | $(Escape-MarkdownCell $Check.Details) |"
}

$ReportLines += ""
$ReportLines += "## Manual Gate 1 Question"
$ReportLines += ""
$ReportLines += "After reading answer_A, answer_B, and final_answer, answer this manually:"
$ReportLines += ""
$ReportLines += "- Is final_answer.md better than answer_A_OpenAI.md?"
$ReportLines += "- Is final_answer.md better than answer_B_Anthropic.md?"
$ReportLines += "- Did the Judge lose any important point from the best single answer?"
$ReportLines += "- Did the Judge invent unsupported details?"
$ReportLines += ""
$ReportLines += "Gate 1 passes only if final_answer usually beats both single answers across real prompts."

try {
    $ReportLines | Set-Content -LiteralPath $ReportPath -Encoding UTF8 -ErrorAction Stop
    Write-Color "[OK] Markdown report: $ReportPath" "Green"
}
catch {
    Write-Color "[ERROR] Failed to write markdown report: $($_.Exception.Message)" "Red"
}

if ($ExportCsvReport -eq $true) {
    try {
        $Checks | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Color "[OK] CSV report: $CsvPath" "Green"
    }
    catch {
        Write-Color "[ERROR] Failed to write CSV report: $($_.Exception.Message)" "Red"
    }
}

if ($OpenMarkdownReport -eq $true) {
    try {
        Start-Process -FilePath "notepad.exe" -ArgumentList $ReportPath | Out-Null
    }
    catch {
        Write-Color "[WARN] Could not open report in Notepad." "Yellow"
    }
}

Write-Host ""
Write-Color "Done." "Cyan"
