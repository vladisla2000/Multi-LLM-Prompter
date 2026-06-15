cls
# ============================================================
# Multi-LLM Prompter - Run Review Helper
# Version: v0.3
# Purpose: Review one completed run folder after a live/API run.
# PowerShell: 5.1 / ISE friendly. ASCII source, UTF-8 BOM, CRLF.
# ============================================================
# Changes in v0.3:
#   1. Reports the optional final verifier (main app v0.8.54+). When a task folder has a
#      final_verification.json, adds a Verifier check: OK when verified=true, WARN when the
#      verifier flagged issues or its call failed. An absent file means RunFinalVerifier was
#      off, so no check is added (no noise). A run-level "verified N/M" line is added to the
#      console and the markdown report when any verifier results are present.
# Changes in v0.2:
#   1. Fixed a parse error. The v0.1 "Reviewed folder" markdown line used a
#      backtick directly before the closing double quote, which escaped the
#      quote (and the $ of the variable), so the string never closed and every
#      line after it mis-parsed. Inline-code spans are now built from single-
#      quoted literals, so no backtick escaping is involved anywhere.
#   2. Rewrote the layout checks for the v0.8.x run folder. A run is now
#      Run_<stamp>\ with AGGREGATE files at the root and one Task_NN subfolder
#      per task (KeepTaskSubfolders = $true is the default). Per-task answer and
#      judge files live inside Task_NN, not flat at the run root.
#   3. Answers are read from answers_raw.json (the old answer_A_OpenAI.md /
#      answer_B_Anthropic.md files no longer exist). Judge files are validated
#      only when the task's router_decision.json reports UseJudge = true, so
#      creative / simple (no-judge) routes are not reported as failures.
#   4. Added a run summary (task count, success/warn counts, tokens, total cost)
#      sourced from task_results_summary.json and cost_summary_by_model.json,
#      plus a per-task results table in the markdown report.
# ============================================================

# -----------------------------
# USER PARAMETERS - EDIT HERE
# -----------------------------

$OutputRoot = "C:\Temp\MultiLLMPrompter"
$RunFolder = ""   # Leave empty to review the latest Run_* folder under $OutputRoot
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
        [string]$Scope = "Run",
        [string]$Area,
        [string]$Check,
        [string]$Status,
        [string]$Details
    )

    $script:Checks += [pscustomobject]@{
        Scope   = $Scope
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

function Get-PropValue {
    param(
        $Object,
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $Prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $Prop) {
        return $Default
    }

    return $Prop.Value
}

function Get-IsTrue {
    param($Value)

    if ($null -eq $Value) {
        return $false
    }

    return ([string]$Value -match "^(True|true|1|yes)$")
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

# Checks one file inside a folder and records a check with the given severity.
# Severity: ERROR (critical, fails the run), WARN (expected on most runs),
#           INFO (optional, never fails). Returns $true if the file exists.
function Test-RunFile {
    param(
        [string]$Folder,
        [string]$Name,
        [string]$Severity = "ERROR",
        [string]$Scope = "Run",
        [string]$Area = "Files"
    )

    $Path = Join-Path $Folder $Name

    if (Test-Path -LiteralPath $Path) {
        $Bytes = 0
        try {
            $Info = Get-Item -LiteralPath $Path -ErrorAction Stop
            $Bytes = [int]$Info.Length
        }
        catch {
            $Bytes = 0
        }
        Add-Check -Scope $Scope -Area $Area -Check $Name -Status "OK" -Details ("Found (" + $Bytes + " bytes)")
        return $true
    }

    if ($Severity -eq "INFO") {
        Add-Check -Scope $Scope -Area $Area -Check $Name -Status "INFO" -Details "Not present (optional)"
    }
    elseif ($Severity -eq "WARN") {
        Add-Check -Scope $Scope -Area $Area -Check $Name -Status "WARN" -Details "Missing (expected on most runs)"
    }
    else {
        Add-Check -Scope $Scope -Area $Area -Check $Name -Status "ERROR" -Details "Missing critical output file"
    }
    return $false
}

# -----------------------------
# MAIN
# -----------------------------

Write-Header "Multi-LLM Prompter Run Review Helper v0.3"

$Checks = @()
$NowStamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ([string]::IsNullOrWhiteSpace($RunFolder)) {
    Write-Color (">>> RunFolder is empty. Searching latest Run_* under: " + $OutputRoot) "Yellow"
    $RunFolder = Get-LatestRunFolder -RootPath $OutputRoot
}

if ([string]::IsNullOrWhiteSpace($RunFolder)) {
    Write-Color "[ERROR] No run folder found." "Red"
    Write-Color 'Set $RunFolder manually or run Multi-LLM Prompter first.' "Yellow"
    return
}

if (-not (Test-Path -LiteralPath $RunFolder)) {
    Write-Color ("[ERROR] Run folder does not exist: " + $RunFolder) "Red"
    return
}

Write-Color ("[INFO] Reviewing: " + $RunFolder) "Gray"

# --- Run-root aggregate files (v0.8.x layout) ---
# Critical: the run did not really complete without these.
Test-RunFile -Folder $RunFolder -Name "tasks.json"                  -Severity "ERROR" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "task_results_summary.json"   -Severity "ERROR" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "final_answer.md"            -Severity "ERROR" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "timing_summary.json"        -Severity "ERROR" -Scope "Run" -Area "Root" | Out-Null

# Important: present on a normal completed run.
Test-RunFile -Folder $RunFolder -Name "input_prompt.txt"           -Severity "WARN" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "task_results_summary.md"    -Severity "WARN" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "cost_summary_by_role.json"  -Severity "WARN" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "cost_summary_by_model.json" -Severity "WARN" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "stage_metrics.csv"         -Severity "WARN" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "request_metrics.csv"      -Severity "WARN" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "errors.json"             -Severity "WARN" -Scope "Run" -Area "Root" | Out-Null

# Optional: route-, GUI-, or condition-specific.
Test-RunFile -Folder $RunFolder -Name "run_metrics.csv"            -Severity "INFO" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "cost_warnings.json"        -Severity "INFO" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "completeness_warnings.json" -Severity "INFO" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "console_transcript.txt"     -Severity "INFO" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "gui_run_report.json"        -Severity "INFO" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "gui_prompt.txt"           -Severity "INFO" -Scope "Run" -Area "Root" | Out-Null
Test-RunFile -Folder $RunFolder -Name "tasks_input.json"        -Severity "INFO" -Scope "Run" -Area "Root" | Out-Null

# --- Combined final answer length ---
$FinalText = Get-FileTextSafe -Path (Join-Path $RunFolder "final_answer.md")
if ($null -ne $FinalText) {
    if ($FinalText.Length -ge $MinimumFinalAnswerChars) {
        Add-Check -Scope "Run" -Area "Final" -Check "final_answer.md length" -Status "OK" -Details ("Length " + $FinalText.Length + " chars")
    }
    else {
        Add-Check -Scope "Run" -Area "Final" -Check "final_answer.md length" -Status "WARN" -Details ("Short final answer: " + $FinalText.Length + " chars")
    }
}

# --- Run-level warning files (non-empty means something to look at) ---
$CostWarnObj = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $RunFolder "cost_warnings.json"))
$CostWarnCount = 0
if ($null -ne $CostWarnObj) { $CostWarnCount = @($CostWarnObj).Count }
if ($CostWarnCount -gt 0) {
    Add-Check -Scope "Run" -Area "Cost" -Check "cost_warnings.json" -Status "WARN" -Details ("Unknown-price model warnings: " + $CostWarnCount)
}

$ComplWarnObj = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $RunFolder "completeness_warnings.json"))
$ComplWarnCount = 0
if ($null -ne $ComplWarnObj) { $ComplWarnCount = @($ComplWarnObj).Count }
if ($ComplWarnCount -gt 0) {
    Add-Check -Scope "Run" -Area "Completeness" -Check "completeness_warnings.json" -Status "WARN" -Details ("Completeness warnings: " + $ComplWarnCount)
}

$RootErrorsObj = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $RunFolder "errors.json"))
$RootErrorCount = 0
if ($null -ne $RootErrorsObj) { $RootErrorCount = @($RootErrorsObj).Count }
if ($RootErrorCount -gt 0) {
    Add-Check -Scope "Run" -Area "Errors" -Check "errors.json" -Status "WARN" -Details ("Run-level error entries: " + $RootErrorCount)
}

# --- Total cost from cost_summary_by_model.json ---
$TotalCost = 0.0
$CostByModel = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $RunFolder "cost_summary_by_model.json"))
if ($null -ne $CostByModel) {
    foreach ($Row in @($CostByModel)) {
        $RowCost = Get-PropValue -Object $Row -Name "EstimatedCostUsd" -Default $null
        if ($null -ne $RowCost) {
            $Parsed = 0.0
            if ([double]::TryParse([string]$RowCost, [ref]$Parsed)) {
                $TotalCost += $Parsed
            }
        }
    }
}

# --- Task summary (aggregate truth for the per-task list) ---
$TaskSummary = @()
$TaskSummaryObj = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $RunFolder "task_results_summary.json"))
if ($null -ne $TaskSummaryObj) {
    $TaskSummary = @($TaskSummaryObj)
    Add-Check -Scope "Run" -Area "Summary" -Check "task_results_summary.json parse" -Status "OK" -Details ("Tasks: " + $TaskSummary.Count)

    $FailedTasks = @($TaskSummary | Where-Object { -not (Get-IsTrue (Get-PropValue -Object $_ -Name "Success" -Default $false)) })
    if ($FailedTasks.Count -eq 0) {
        Add-Check -Scope "Run" -Area "Summary" -Check "task success" -Status "OK" -Details "All tasks report Success = true"
    }
    else {
        $FailIds = @($FailedTasks | ForEach-Object { [string](Get-PropValue -Object $_ -Name "TaskId" -Default "?") }) -join ", "
        Add-Check -Scope "Run" -Area "Summary" -Check "task success" -Status "ERROR" -Details ("Failed task ids: " + $FailIds)
    }

    $WarnTasks = @($TaskSummary | Where-Object { Get-IsTrue (Get-PropValue -Object $_ -Name "CompletenessWarning" -Default $false) })
    if ($WarnTasks.Count -gt 0) {
        $WarnIds = @($WarnTasks | ForEach-Object { [string](Get-PropValue -Object $_ -Name "TaskId" -Default "?") }) -join ", "
        Add-Check -Scope "Run" -Area "Summary" -Check "completeness" -Status "WARN" -Details ("Completeness-flagged task ids: " + $WarnIds)
    }
}
else {
    Add-Check -Scope "Run" -Area "Summary" -Check "task_results_summary.json parse" -Status "ERROR" -Details "Cannot parse task_results_summary.json"
}

# --- Per-task subfolders (Task_NN). Flat fallback if none exist. ---
$TaskFolders = @(Get-ChildItem -LiteralPath $RunFolder -Directory -Filter "Task_*" -ErrorAction SilentlyContinue | Sort-Object Name)

if ($TaskFolders.Count -eq 0) {
    # Flat layout (KeepTaskSubfolders = $false): per-task files sit at the run root.
    Add-Check -Scope "Run" -Area "Layout" -Check "task subfolders" -Status "INFO" -Details "No Task_* folders; treating run root as a single flat task"
    $TaskScopes = @([pscustomobject]@{ Name = "Task (flat)"; Path = $RunFolder })
}
else {
    $TaskScopes = @($TaskFolders | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Path = $_.FullName } })
}

foreach ($TaskScope in $TaskScopes) {
    $Scope = $TaskScope.Name
    $TaskPath = $TaskScope.Path

    # Router decision drives what is expected for this task.
    $Router = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $TaskPath "router_decision.json"))
    if ($null -ne $Router) {
        $RTaskType = [string](Get-PropValue -Object $Router -Name "TaskType" -Default "")
        $RWorkMode = [string](Get-PropValue -Object $Router -Name "WorkMode" -Default "")
        $RUseJudge = Get-IsTrue (Get-PropValue -Object $Router -Name "UseJudge" -Default $false)
        $RUseOpenAI = Get-IsTrue (Get-PropValue -Object $Router -Name "UseOpenAI" -Default $false)
        $RUseAnthropic = Get-IsTrue (Get-PropValue -Object $Router -Name "UseAnthropicAnswer" -Default $false)
        Add-Check -Scope $Scope -Area "Routing" -Check "router_decision.json" -Status "OK" -Details ("Type=" + $RTaskType + "; WorkMode=" + $RWorkMode + "; UseJudge=" + $RUseJudge)
    }
    else {
        $RTaskType = ""
        $RWorkMode = ""
        $RUseJudge = $false
        $RUseOpenAI = $false
        $RUseAnthropic = $false
        Add-Check -Scope $Scope -Area "Routing" -Check "router_decision.json" -Status "WARN" -Details "Missing or unreadable; cannot confirm expected answers/judge"
    }

    # Core per-task outputs.
    Test-RunFile -Folder $TaskPath -Name "input_prompt.txt"     -Severity "WARN" -Scope $Scope -Area "Files" | Out-Null
    Test-RunFile -Folder $TaskPath -Name "effective_prompt.txt" -Severity "INFO" -Scope $Scope -Area "Files" | Out-Null

    $TaskFinalText = Get-FileTextSafe -Path (Join-Path $TaskPath "final_answer.md")
    if ($null -ne $TaskFinalText) {
        if ($TaskFinalText.Length -ge 50) {
            Add-Check -Scope $Scope -Area "Final" -Check "final_answer.md" -Status "OK" -Details ("Length " + $TaskFinalText.Length + " chars")
        }
        else {
            Add-Check -Scope $Scope -Area "Final" -Check "final_answer.md" -Status "WARN" -Details ("Very short: " + $TaskFinalText.Length + " chars")
        }
    }
    else {
        Add-Check -Scope $Scope -Area "Final" -Check "final_answer.md" -Status "ERROR" -Details "Missing per-task final answer"
    }

    # Answers (read from answers_raw.json; no per-answer .md files in v0.8.x).
    $AnswersObj = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $TaskPath "answers_raw.json"))
    if ($null -ne $AnswersObj) {
        $AnswerCount = @($AnswersObj).Count
        $Expected = 0
        if ($null -ne $Router) {
            if ($RUseOpenAI) { $Expected++ }
            if ($RUseAnthropic) { $Expected++ }
        }

        if ($Expected -gt 0 -and $AnswerCount -lt $Expected) {
            Add-Check -Scope $Scope -Area "Answers" -Check "answers_raw.json" -Status "WARN" -Details ("Got " + $AnswerCount + " answer(s); expected " + $Expected)
        }
        elseif ($AnswerCount -eq 0) {
            Add-Check -Scope $Scope -Area "Answers" -Check "answers_raw.json" -Status "WARN" -Details "No answers recorded"
        }
        else {
            Add-Check -Scope $Scope -Area "Answers" -Check "answers_raw.json" -Status "OK" -Details ("Answers recorded: " + $AnswerCount)
        }
    }
    else {
        Add-Check -Scope $Scope -Area "Answers" -Check "answers_raw.json" -Status "WARN" -Details "Missing or unparseable"
    }

    # Per-task error file.
    $TaskErrObj = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $TaskPath "errors.json"))
    $TaskErrCount = 0
    if ($null -ne $TaskErrObj) { $TaskErrCount = @($TaskErrObj).Count }
    if ($TaskErrCount -gt 0) {
        Add-Check -Scope $Scope -Area "Errors" -Check "errors.json" -Status "WARN" -Details ("Error entries: " + $TaskErrCount)
    }

    # Judge files - validated only when the route used a judge.
    $JudgeText = Get-FileTextSafe -Path (Join-Path $TaskPath "judge_text.txt")
    $JudgeRan = ($null -ne $JudgeText)

    if ($RUseJudge -or ($null -eq $Router -and $JudgeRan)) {
        if ($JudgeRan) {
            $Markers = @(
                [pscustomobject]@{ Marker = "---JUDGE_JSON---";            Severity = "ERROR" },
                [pscustomobject]@{ Marker = "---FINAL_ANSWER_MARKDOWN---"; Severity = "ERROR" },
                [pscustomobject]@{ Marker = "---IMPROVED_PROMPT---";       Severity = "WARN"  }
            )
            foreach ($M in $Markers) {
                if ($JudgeText.Contains($M.Marker)) {
                    Add-Check -Scope $Scope -Area "Judge" -Check ($M.Marker + " marker") -Status "OK" -Details "Marker present"
                }
                else {
                    Add-Check -Scope $Scope -Area "Judge" -Check ($M.Marker + " marker") -Status $M.Severity -Details "Marker missing"
                }
            }

            $JudgeParsed = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $TaskPath "judge_parsed.json"))
            if ($null -ne $JudgeParsed) {
                $BestId = [string](Get-PropValue -Object $JudgeParsed -Name "best_answer_id" -Default "")
                $Conf = [string](Get-PropValue -Object $JudgeParsed -Name "confidence" -Default "")
                Add-Check -Scope $Scope -Area "Judge" -Check "judge_parsed.json" -Status "OK" -Details ("best_answer_id=" + $BestId + "; confidence=" + $Conf)
            }
            else {
                Add-Check -Scope $Scope -Area "Judge" -Check "judge_parsed.json" -Status "ERROR" -Details "Cannot parse judge_parsed.json"
            }
        }
        else {
            Add-Check -Scope $Scope -Area "Judge" -Check "judge_text.txt" -Status "ERROR" -Details "Route used a judge (UseJudge=true) but judge_text.txt is missing"
        }
    }
    else {
        $WhyNoJudge = "route does not use a judge"
        if ($RTaskType -ne "") { $WhyNoJudge = "TaskType=" + $RTaskType + " does not use a judge" }
        Add-Check -Scope $Scope -Area "Judge" -Check "judge (skipped)" -Status "INFO" -Details $WhyNoJudge
    }

    # Final verifier (main app v0.8.54+): only present when RunFinalVerifier was on.
    # Absent file = verifier not run, so no check is added.
    $VerObj = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $TaskPath "final_verification.json"))
    if ($null -ne $VerObj) {
        $VerSuccess = Get-IsTrue (Get-PropValue -Object $VerObj -Name "Success" -Default $false)
        $VerVerified = Get-PropValue -Object $VerObj -Name "Verified" -Default $null
        $VerConf = [string](Get-PropValue -Object $VerObj -Name "Confidence" -Default "")
        $VerIssues = @(Get-PropValue -Object $VerObj -Name "Issues" -Default @())
        if (-not $VerSuccess) {
            Add-Check -Scope $Scope -Area "Verifier" -Check "final_verification.json" -Status "WARN" -Details ("Verifier call did not succeed: " + [string](Get-PropValue -Object $VerObj -Name "Error" -Default ""))
        }
        elseif ($VerVerified -eq $true) {
            Add-Check -Scope $Scope -Area "Verifier" -Check "final answer verified" -Status "OK" -Details ("verified=true; confidence=" + $VerConf + "; issues=" + $VerIssues.Count)
        }
        else {
            $IssueText = (@($VerIssues) | Select-Object -First 3) -join "; "
            $VerDetail = "verified=" + $VerVerified + "; confidence=" + $VerConf + "; issues=" + $VerIssues.Count
            if (-not [string]::IsNullOrWhiteSpace($IssueText)) { $VerDetail = $VerDetail + " (" + $IssueText + ")" }
            Add-Check -Scope $Scope -Area "Verifier" -Check "final answer verified" -Status "WARN" -Details $VerDetail
        }
    }
}

# -----------------------------
# SUMMARY
# -----------------------------

$ErrorCount = @($Checks | Where-Object { $_.Status -eq "ERROR" }).Count
$WarnCount = @($Checks | Where-Object { $_.Status -eq "WARN" }).Count
$OkCount = @($Checks | Where-Object { $_.Status -eq "OK" }).Count
$InfoCount = @($Checks | Where-Object { $_.Status -eq "INFO" }).Count

$VerChecks = @($Checks | Where-Object { $_.Area -eq "Verifier" })
$VerOkCount = @($VerChecks | Where-Object { $_.Status -eq "OK" }).Count
$VerTotal = $VerChecks.Count

if ($ErrorCount -eq 0 -and $WarnCount -eq 0) {
    $Overall = "PASS"
}
elseif ($ErrorCount -eq 0 -and $WarnCount -gt 0) {
    $Overall = "PASS_WITH_WARNINGS"
}
else {
    $Overall = "FAIL"
}

Write-Header ("Review Result: " + $Overall)
Write-Color ("Tasks: " + $TaskScopes.Count + "   Total est. cost: $" + ("{0:N4}" -f $TotalCost)) "White"
Write-Color ("OK: " + $OkCount + "   WARN: " + $WarnCount + "   ERROR: " + $ErrorCount + "   INFO: " + $InfoCount) "White"
if ($VerTotal -gt 0) { Write-Color ("Final verifier: " + $VerOkCount + "/" + $VerTotal + " task final answer(s) verified") "White" }
Write-Host ""

foreach ($Check in $Checks) {
    $Line = "[" + $Check.Status + "] " + $Check.Scope + " / " + $Check.Area + " - " + $Check.Check + ": " + $Check.Details
    if ($Check.Status -eq "OK") {
        Write-Color $Line "Green"
    }
    elseif ($Check.Status -eq "WARN") {
        Write-Color $Line "Yellow"
    }
    elseif ($Check.Status -eq "INFO") {
        Write-Color $Line "Gray"
    }
    else {
        Write-Color $Line "Red"
    }
}

# -----------------------------
# REPORTS
# -----------------------------

$ReportPath = Join-Path $RunFolder ("run_review_" + $NowStamp + ".md")
$CsvPath = Join-Path $RunFolder ("run_review_" + $NowStamp + ".csv")

$ReportLines = @()
$ReportLines += "# Multi-LLM Prompter Run Review"
$ReportLines += ""
# Inline-code span built from single-quoted literals so no backtick escaping is needed.
$ReportLines += ('- Reviewed folder: `' + $RunFolder + '`')
$ReportLines += ("- Review time: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$ReportLines += ("- Overall: **" + $Overall + "**")
$ReportLines += ("- Tasks: " + $TaskScopes.Count)
$ReportLines += ("- Total estimated cost (USD): " + ("{0:N4}" -f $TotalCost))
$ReportLines += ("- OK: " + $OkCount)
$ReportLines += ("- WARN: " + $WarnCount)
$ReportLines += ("- ERROR: " + $ErrorCount)
$ReportLines += ("- INFO: " + $InfoCount)
if ($VerTotal -gt 0) { $ReportLines += ("- Final verifier: " + $VerOkCount + "/" + $VerTotal + " task final answer(s) verified") }
$ReportLines += ""

if ($TaskSummary.Count -gt 0) {
    $ReportLines += "## Tasks"
    $ReportLines += ""
    $ReportLines += "| Id | Type | Work | Success | Answers | Judge | Compl | Tokens | Cost USD | Title |"
    $ReportLines += "|---|---|---|---|---|---|---|---|---|---|"
    foreach ($T in $TaskSummary) {
        $ReportLines += ("| " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "TaskId" -Default ""))) + " | " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "TaskType" -Default ""))) + " | " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "WorkMode" -Default ""))) + " | " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "Success" -Default ""))) + " | " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "AnswerCount" -Default ""))) + " | " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "JudgeMode" -Default ""))) + " | " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "CompletenessWarning" -Default ""))) + " | " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "TotalTokens" -Default ""))) + " | " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "EstimatedCostUsd" -Default ""))) + " | " +
            (Escape-MarkdownCell ([string](Get-PropValue -Object $T -Name "TaskTitle" -Default ""))) + " |")
    }
    $ReportLines += ""
}

$ReportLines += "## Checks"
$ReportLines += ""
$ReportLines += "| Scope | Area | Check | Status | Details |"
$ReportLines += "|---|---|---|---|---|"

foreach ($Check in $Checks) {
    $ReportLines += ("| " +
        (Escape-MarkdownCell $Check.Scope) + " | " +
        (Escape-MarkdownCell $Check.Area) + " | " +
        (Escape-MarkdownCell $Check.Check) + " | " +
        (Escape-MarkdownCell $Check.Status) + " | " +
        (Escape-MarkdownCell $Check.Details) + " |")
}

$ReportLines += ""
$ReportLines += "## Manual Gate 1 Questions"
$ReportLines += ""
$ReportLines += "After reading the per-task answers (answers_raw.json) and final_answer.md, answer manually:"
$ReportLines += ""
$ReportLines += "- Is final_answer.md better than the single best answer in answers_raw.json?"
$ReportLines += "- Did the Judge lose any important point from the best single answer?"
$ReportLines += "- Did the Judge invent unsupported details?"
$ReportLines += ""
$ReportLines += "Gate 1 passes only if final_answer usually beats both single answers across real prompts."

try {
    $ReportLines | Set-Content -LiteralPath $ReportPath -Encoding UTF8 -ErrorAction Stop
    Write-Color ("[OK] Markdown report: " + $ReportPath) "Green"
}
catch {
    Write-Color ("[ERROR] Failed to write markdown report: " + $_.Exception.Message) "Red"
}

if ($ExportCsvReport -eq $true) {
    try {
        $Checks | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Color ("[OK] CSV report: " + $CsvPath) "Green"
    }
    catch {
        Write-Color ("[ERROR] Failed to write CSV report: " + $_.Exception.Message) "Red"
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
