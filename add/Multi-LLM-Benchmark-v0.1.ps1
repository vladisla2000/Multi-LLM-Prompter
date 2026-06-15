cls
# ============================================================
# Multi-LLM Prompter - Benchmark Runner
# Version: v0.1
# Purpose: Run the Gate-1 benchmark prompt set through the existing pipeline and
#   produce a comparison report (routing accuracy, judge verdicts, cost/tokens/time).
# PowerShell: 5.1 / ISE friendly. ASCII source, UTF-8 BOM, CRLF.
#
# HOW IT WORKS (no changes to the main app):
#   This is a standalone driver, like the run-review helper. It reads the Gate-1 CSV,
#   builds a tasks_input.json from the prompts, pre-creates a run folder, and starts the
#   main Multi-LLM-Prompter-v*.ps1 as a HEADLESS child (the same env-var contract the GUI
#   uses: MULTILLM_HEADLESS / _RUNFOLDER / _PROMPT_FILE / _TASKS_FILE / model vars). The
#   child runs the real pipeline (router -> 2 answers -> judge) over every benchmark prompt,
#   then this script reads task_results_summary.json + each Task_NN/judge_parsed.json and
#   writes benchmark_results.csv + benchmark_summary.md.
#
# COST WARNING: a live run makes real API calls and spends real money - roughly
#   (number of selected prompts) x (2 answer models + 1 judge). code/technical/ui_code
#   prompts use the strong Opus judge in Full mode by policy, so they dominate cost.
#   DryRun is ON by default; set $DryRun = $false to actually run.
# ============================================================

# -----------------------------
# USER PARAMETERS - EDIT HERE
# -----------------------------

$DryRun = $true                 # TRUE = build inputs + show the plan, NO pipeline, NO API calls, NO cost.
$ReportOnlyRunFolder = ""       # Set to an existing benchmark Run_* folder to JUST (re)build the report from it.

$MainScriptPath = ""            # empty => newest Multi-LLM-Prompter-v*.ps1 in the parent folder
$BenchmarkCsvPath = ""          # empty => Multi-LLM-Gate1-Benchmark-Prompts.csv next to this script
$OutputRoot = "C:\Temp\MultiLLMPrompter"

$ExcludeIds = @(10, 11)         # CSV Ids to skip (10 = invalid-key failure test, 11 = proxy test - operational, not content)
$MaxPrompts = 0                 # 0 = all selected; otherwise cap the number of prompts

# Optional model overrides (empty => use the main app's config/defaults).
# NOTE: Full comparison mode ALWAYS uses the strong judge by policy; these do not weaken it.
$AnswerModelOpenAI = ""
$AnswerModelAnthropic = ""
$JudgeModel = ""
$UseReviewJudge = $false        # cheap/review judge for Light/ReviewOnly tasks

$PipelineTimeoutSec = 1800      # max wait for the whole batch before giving up
$OpenSummary = $true            # open benchmark_summary.md in Notepad when done

# -----------------------------
# FUNCTIONS
# -----------------------------

function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Resolve-ScriptFolder {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { return $PSScriptRoot }
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) { return (Split-Path -Path $PSCommandPath -Parent) }
    if ($null -ne $MyInvocation.MyCommand.Path) { return (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) }
    return (Get-Location).Path
}

function Get-NewestByVersion {
    param([string]$Folder, [string]$Filter)
    if (-not (Test-Path -LiteralPath $Folder)) { return $null }
    $Files = @(Get-ChildItem -LiteralPath $Folder -Filter $Filter -File -ErrorAction SilentlyContinue)
    if ($Files.Count -eq 0) { return $null }
    $Ranked = $Files | ForEach-Object {
        $Key = 0
        if ($_.Name -match 'v(\d+(?:[._]\d+)*)') {
            $Parts = $Matches[1] -split '[._]'
            for ($i = 0; $i -lt 4; $i++) {
                $Val = 0
                if ($i -lt $Parts.Count) { $Val = [int]$Parts[$i] }
                $Key = ($Key * 1000) + $Val
            }
        }
        [pscustomobject]@{ File = $_; Key = $Key }
    }
    return ($Ranked | Sort-Object Key | Select-Object -Last 1).File.FullName
}

function Get-FileTextSafe {
    param([string]$Path)
    try {
        if (Test-Path -LiteralPath $Path) { return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop) }
        return $null
    }
    catch { return $null }
}

function ConvertFrom-JsonSafe {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    try { return ($Text | ConvertFrom-Json -ErrorAction Stop) }
    catch { return $null }
}

function Get-PropValue {
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $Prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $Prop) { return $Default }
    return $Prop.Value
}

function Get-IsTrue {
    param($Value)
    if ($null -eq $Value) { return $false }
    return ([string]$Value -match "^(True|true|1|yes)$")
}

function Get-ShortText {
    param([string]$Text, [int]$Max = 80)
    if ($null -eq $Text) { return "" }
    $One = ($Text -replace "\s+", " ").Trim()
    if ($One.Length -le $Max) { return $One }
    return ($One.Substring(0, $Max) + "...")
}

function Escape-MarkdownCell {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $V = $Text.Replace("|", "\|").Replace("`r", " ").Replace("`n", " ")
    return $V
}

function Save-Utf8 {
    param([string]$Path, [string]$Text)
    $Enc = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Text, $Enc)
}

# Build the per-prompt result rows from a completed run folder, cross-referenced
# against the benchmark map (TaskId -> CSV Id / Category / ExpectedTaskType).
function Get-BenchmarkRows {
    param([string]$RunFolder, $TaskMap)

    $Rows = @()
    $Summary = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $RunFolder "task_results_summary.json"))
    if ($null -eq $Summary) { return $Rows }

    foreach ($T in @($Summary)) {
        $TaskId = [int](Get-PropValue -Object $T -Name "TaskId" -Default 0)
        $Meta = $null
        if ($null -ne $TaskMap) { $Meta = $TaskMap[$TaskId] }

        $ActualType = [string](Get-PropValue -Object $T -Name "TaskType" -Default "")
        $ExpectedType = ""
        $CsvId = $TaskId
        $Category = ""
        if ($null -ne $Meta) {
            $ExpectedType = [string]$Meta.ExpectedTaskType
            $CsvId = $Meta.CsvId
            $Category = [string]$Meta.Category
        }
        $TypeMatch = ""
        if (-not [string]::IsNullOrWhiteSpace($ExpectedType)) {
            $TypeMatch = $(if ($ActualType -eq $ExpectedType) { "Y" } else { "N" })
        }

        # Judge specifics from the per-task folder.
        $TaskFolder = [string](Get-PropValue -Object $T -Name "TaskFolder" -Default "")
        if ([string]::IsNullOrWhiteSpace($TaskFolder) -or -not (Test-Path -LiteralPath $TaskFolder)) {
            $TaskFolder = Join-Path $RunFolder ("Task_" + ("{0:00}" -f $TaskId))
        }
        $Judge = ConvertFrom-JsonSafe -Text (Get-FileTextSafe -Path (Join-Path $TaskFolder "judge_parsed.json"))
        $BestAnswer = [string](Get-PropValue -Object $Judge -Name "best_answer_id" -Default "")
        $Confidence = [string](Get-PropValue -Object $Judge -Name "confidence" -Default "")
        $Source = Get-PropValue -Object $Judge -Name "final_answer_source" -Default $null
        $SrcA = [string](Get-PropValue -Object $Source -Name "A" -Default "")
        $SrcB = [string](Get-PropValue -Object $Source -Name "B" -Default "")

        $Rows += [pscustomobject]@{
            CsvId            = $CsvId
            Category         = $Category
            ExpectedTaskType = $ExpectedType
            ActualTaskType   = $ActualType
            TypeMatch        = $TypeMatch
            WorkMode         = [string](Get-PropValue -Object $T -Name "WorkMode" -Default "")
            JudgeMode        = [string](Get-PropValue -Object $T -Name "JudgeMode" -Default "")
            JudgeModel       = [string](Get-PropValue -Object $T -Name "JudgeModelUsed" -Default "")
            BestAnswer       = $BestAnswer
            Confidence       = $Confidence
            FinalSourceA     = $SrcA
            FinalSourceB     = $SrcB
            Success          = [string](Get-PropValue -Object $T -Name "Success" -Default "")
            Completeness     = $(if (Get-IsTrue (Get-PropValue -Object $T -Name "CompletenessWarning" -Default $false)) { "WARN" } else { "OK" })
            InputTokens      = [int](Get-PropValue -Object $T -Name "InputTokens" -Default 0)
            OutputTokens     = [int](Get-PropValue -Object $T -Name "OutputTokens" -Default 0)
            TotalTokens      = [int](Get-PropValue -Object $T -Name "TotalTokens" -Default 0)
            CostUsd          = [double](Get-PropValue -Object $T -Name "EstimatedCostUsd" -Default 0)
            Error            = [string](Get-PropValue -Object $T -Name "Error" -Default "")
        }
    }
    return $Rows
}

# Write benchmark_results.csv + benchmark_summary.md into $RunFolder.
function Write-BenchmarkReport {
    param([string]$RunFolder, $Rows, [string]$ModelsLine)

    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $CsvPath = Join-Path $RunFolder "benchmark_results.csv"
    $MdPath = Join-Path $RunFolder "benchmark_summary.md"

    @($Rows) | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8 -ErrorAction SilentlyContinue

    $N = @($Rows).Count
    $Rated = @($Rows | Where-Object { $_.TypeMatch -eq "Y" -or $_.TypeMatch -eq "N" })
    $TypeOk = @($Rows | Where-Object { $_.TypeMatch -eq "Y" }).Count
    $RoutingPct = ""
    if ($Rated.Count -gt 0) { $RoutingPct = ("{0:N0}" -f (100.0 * $TypeOk / $Rated.Count)) + "% (" + $TypeOk + "/" + $Rated.Count + ")" }

    $BestA = @($Rows | Where-Object { $_.BestAnswer -eq "A" }).Count
    $BestB = @($Rows | Where-Object { $_.BestAnswer -eq "B" }).Count
    $BestOther = $N - $BestA - $BestB
    $Failures = @($Rows | Where-Object { -not (Get-IsTrue $_.Success) }).Count
    $Warns = @($Rows | Where-Object { $_.Completeness -eq "WARN" }).Count

    $TotalCost = 0.0
    $TotalTokens = 0
    foreach ($R in $Rows) { $TotalCost += [double]$R.CostUsd; $TotalTokens += [int]$R.TotalTokens }
    $AvgCost = 0.0
    if ($N -gt 0) { $AvgCost = $TotalCost / $N }

    $L = @()
    $L += "# Multi-LLM Prompter - Gate-1 Benchmark Summary"
    $L += ""
    $L += ('- Run folder: `' + $RunFolder + '`')
    $L += ("- Generated: " + $Stamp)
    $L += ("- Models: " + $ModelsLine)
    $L += ("- Prompts: " + $N)
    $L += ("- Routing accuracy (actual TaskType == ExpectedTaskType): " + $RoutingPct)
    $L += ("- Judge best answer: A=" + $BestA + "  B=" + $BestB + "  other/none=" + $BestOther)
    $L += ("- Failures: " + $Failures + "   Completeness warnings: " + $Warns)
    $L += ("- Total estimated cost (USD): " + ("{0:N4}" -f $TotalCost))
    $L += ("- Average cost per prompt (USD): " + ("{0:N4}" -f $AvgCost))
    $L += ("- Total tokens: " + $TotalTokens)
    $L += ""
    $L += "## Per-prompt results"
    $L += ""
    $L += "| Id | Category | Expected | Actual | Match | Work | Judge | Best | Conf | A% | B% | OK | Compl | Tokens | Cost USD |"
    $L += "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"
    foreach ($R in $Rows) {
        $L += ("| " +
            (Escape-MarkdownCell ([string]$R.CsvId)) + " | " +
            (Escape-MarkdownCell ([string]$R.Category)) + " | " +
            (Escape-MarkdownCell ([string]$R.ExpectedTaskType)) + " | " +
            (Escape-MarkdownCell ([string]$R.ActualTaskType)) + " | " +
            (Escape-MarkdownCell ([string]$R.TypeMatch)) + " | " +
            (Escape-MarkdownCell ([string]$R.WorkMode)) + " | " +
            (Escape-MarkdownCell ([string]$R.JudgeMode)) + " | " +
            (Escape-MarkdownCell ([string]$R.BestAnswer)) + " | " +
            (Escape-MarkdownCell ([string]$R.Confidence)) + " | " +
            (Escape-MarkdownCell ([string]$R.FinalSourceA)) + " | " +
            (Escape-MarkdownCell ([string]$R.FinalSourceB)) + " | " +
            (Escape-MarkdownCell ([string]$R.Success)) + " | " +
            (Escape-MarkdownCell ([string]$R.Completeness)) + " | " +
            (Escape-MarkdownCell ([string]$R.TotalTokens)) + " | " +
            (Escape-MarkdownCell ("{0:N4}" -f [double]$R.CostUsd)) + " |")
    }
    $L += ""
    $L += "## Gate-1 manual judgment (not automated)"
    $L += ""
    $L += "The objective data above is automated. The Gate-1 verdict still needs a human read:"
    $L += "for each prompt, open the per-task answers (Task_NN/answers_raw.json) and final_answer.md and"
    $L += "decide whether the synthesized final beats the single best answer, lost any key point, or"
    $L += "invented unsupported detail. Gate 1 passes only if the final usually beats both singles."

    Save-Utf8 -Path $MdPath -Text (($L -join "`r`n") + "`r`n")

    Write-Color ("[OK] Results CSV : " + $CsvPath) "Green"
    Write-Color ("[OK] Summary MD  : " + $MdPath) "Green"
    return $MdPath
}

# -----------------------------
# MAIN
# -----------------------------

Write-Header "Multi-LLM Prompter Benchmark Runner v0.1"

$ScriptFolder = Resolve-ScriptFolder
$ParentFolder = Split-Path -Path $ScriptFolder -Parent

if ([string]::IsNullOrWhiteSpace($MainScriptPath)) {
    $MainScriptPath = Get-NewestByVersion -Folder $ParentFolder -Filter "Multi-LLM-Prompter-v*.ps1"
}
if ([string]::IsNullOrWhiteSpace($BenchmarkCsvPath)) {
    $BenchmarkCsvPath = Join-Path $ScriptFolder "Multi-LLM-Gate1-Benchmark-Prompts.csv"
}

# ---- Report-only mode: just (re)build the report from an existing run folder ----
if (-not [string]::IsNullOrWhiteSpace($ReportOnlyRunFolder)) {
    if (-not (Test-Path -LiteralPath $ReportOnlyRunFolder)) {
        Write-Color ("[ERROR] ReportOnlyRunFolder not found: " + $ReportOnlyRunFolder) "Red"
        return
    }
    Write-Color ("[INFO] Report-only: " + $ReportOnlyRunFolder) "Gray"
    # Rebuild the TaskId -> CSV map from the CSV (best-effort; assumes same selection order).
    $TaskMap = @{}
    if (Test-Path -LiteralPath $BenchmarkCsvPath) {
        $Csv = @(Import-Csv -LiteralPath $BenchmarkCsvPath)
        $Sel = @($Csv | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Prompt) -and ($ExcludeIds -notcontains [int]$_.Id) })
        if ($MaxPrompts -gt 0 -and $Sel.Count -gt $MaxPrompts) { $Sel = $Sel[0..($MaxPrompts - 1)] }
        $Tid = 0
        foreach ($Row in $Sel) {
            $Tid++
            $TaskMap[$Tid] = [pscustomobject]@{ CsvId = $Row.Id; Category = $Row.Category; ExpectedTaskType = $Row.ExpectedTaskType }
        }
    }
    $Rows = Get-BenchmarkRows -RunFolder $ReportOnlyRunFolder -TaskMap $TaskMap
    if (@($Rows).Count -eq 0) {
        Write-Color "[ERROR] No task results found in that folder (task_results_summary.json missing/empty)." "Red"
        return
    }
    $Md = Write-BenchmarkReport -RunFolder $ReportOnlyRunFolder -Rows $Rows -ModelsLine "(report-only; see the run's own config)"
    if ($OpenSummary -eq $true) { try { Start-Process notepad.exe $Md | Out-Null } catch { } }
    Write-Color "Done." "Cyan"
    return
}

# ---- Validate inputs ----
if ([string]::IsNullOrWhiteSpace($MainScriptPath) -or -not (Test-Path -LiteralPath $MainScriptPath)) {
    Write-Color "[ERROR] Could not locate the main Multi-LLM-Prompter-v*.ps1. Set `$MainScriptPath." "Red"
    return
}
if (-not (Test-Path -LiteralPath $BenchmarkCsvPath)) {
    Write-Color ("[ERROR] Benchmark CSV not found: " + $BenchmarkCsvPath) "Red"
    return
}

Write-Color ("Main script : " + $MainScriptPath) "Gray"
Write-Color ("Benchmark   : " + $BenchmarkCsvPath) "Gray"

# ---- Select prompts ----
$Csv = @(Import-Csv -LiteralPath $BenchmarkCsvPath)
$Selected = @($Csv | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Prompt) -and ($ExcludeIds -notcontains [int]$_.Id) })
if ($MaxPrompts -gt 0 -and $Selected.Count -gt $MaxPrompts) { $Selected = $Selected[0..($MaxPrompts - 1)] }

if ($Selected.Count -eq 0) {
    Write-Color "[ERROR] No prompts selected from the CSV (check ExcludeIds / Prompt column)." "Red"
    return
}

# Build the task list + TaskId -> CSV map.
$Tasks = @()
$TaskMap = @{}
$Tid = 0
foreach ($Row in $Selected) {
    $Tid++
    $Title = ("[" + $Row.Id + "] " + $Row.Category)
    $Tasks += [pscustomobject]@{
        TaskId           = $Tid
        TaskTitle        = $Title
        PromptText       = [string]$Row.Prompt
        TypeOverride     = ""
        WorkModeOverride = ""
    }
    $TaskMap[$Tid] = [pscustomobject]@{ CsvId = $Row.Id; Category = $Row.Category; ExpectedTaskType = $Row.ExpectedTaskType }
}

Write-Color ("Selected prompts: " + $Tasks.Count + " (excluded ids: " + ($ExcludeIds -join ", ") + ")") "Green"
foreach ($T in $Tasks) {
    $Meta = $TaskMap[$T.TaskId]
    Write-Color ("  Task " + $T.TaskId + " <- CSV #" + $Meta.CsvId + " [" + $Meta.ExpectedTaskType + "] " + (Get-ShortText -Text $T.PromptText -Max 70)) "Gray"
}

# ---- DryRun: write the task list for inspection and stop (no pipeline, no cost) ----
if ($DryRun -eq $true) {
    $PreviewDir = Join-Path $OutputRoot "benchmark_preview"
    if (-not (Test-Path -LiteralPath $PreviewDir)) { New-Item -ItemType Directory -Path $PreviewDir -Force | Out-Null }
    $PreviewTasks = Join-Path $PreviewDir "tasks_input.json"
    Save-Utf8 -Path $PreviewTasks -Text ($Tasks | ConvertTo-Json -Depth 5)
    Write-Host ""
    Write-Color "DRY RUN - no pipeline started, no API calls, no cost." "Yellow"
    Write-Color ("Task list written for inspection: " + $PreviewTasks) "Yellow"
    Write-Color ("To run for real: set `$DryRun = `$false (this will make ~" + ($Tasks.Count * 3) + " API calls and spend real money).") "Yellow"
    Write-Color "Done." "Cyan"
    return
}

# ---- LIVE run ----
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$RunFolder = Join-Path $OutputRoot ("Run_benchmark_" + $TimeStamp)
New-Item -ItemType Directory -Path $RunFolder -Force | Out-Null

$PromptFile = Join-Path $RunFolder "gui_prompt.txt"
Save-Utf8 -Path $PromptFile -Text ("Gate-1 benchmark batch: " + $Tasks.Count + " prompts from " + (Split-Path $BenchmarkCsvPath -Leaf))
$TasksFile = Join-Path $RunFolder "tasks_input.json"
Save-Utf8 -Path $TasksFile -Text ($Tasks | ConvertTo-Json -Depth 5)

$ModelsLine = "answer A/B + judge from config unless overridden"
if (-not [string]::IsNullOrWhiteSpace($AnswerModelOpenAI)) { $ModelsLine = "A=" + $AnswerModelOpenAI }
if (-not [string]::IsNullOrWhiteSpace($AnswerModelAnthropic)) { $ModelsLine = $ModelsLine + " B=" + $AnswerModelAnthropic }
if (-not [string]::IsNullOrWhiteSpace($JudgeModel)) { $ModelsLine = $ModelsLine + " judge=" + $JudgeModel }

Write-Color ("Run folder: " + $RunFolder) "Gray"
Write-Color ("Starting headless pipeline over " + $Tasks.Count + " prompts (this spends real money)...") "Yellow"

# Set the GUI->child env contract, then start the main script headless.
$env:MULTILLM_HEADLESS = "1"
$env:MULTILLM_RUNFOLDER = $RunFolder
$env:MULTILLM_PROMPT_FILE = $PromptFile
$env:MULTILLM_TASKS_FILE = $TasksFile
$env:MULTILLM_SPLITMODE = "None"
$env:MULTILLM_WORKMODE = "Auto"
$env:MULTILLM_CHEAP_JUDGE = $(if ($UseReviewJudge) { "1" } else { "0" })
if (-not [string]::IsNullOrWhiteSpace($AnswerModelOpenAI)) { $env:MULTILLM_MODEL_OPENAI = $AnswerModelOpenAI }
if (-not [string]::IsNullOrWhiteSpace($AnswerModelAnthropic)) { $env:MULTILLM_MODEL_ANTHROPIC = $AnswerModelAnthropic }
if (-not [string]::IsNullOrWhiteSpace($JudgeModel)) { $env:MULTILLM_MODEL_JUDGE = $JudgeModel }

$ExitOk = $false
try {
    $Proc = Start-Process powershell.exe -PassThru -WindowStyle Hidden -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $MainScriptPath)
    if ($null -ne $Proc) {
        $Done = $Proc.WaitForExit($PipelineTimeoutSec * 1000)
        if (-not $Done) {
            Write-Color ("[ERROR] Pipeline did not finish within " + $PipelineTimeoutSec + "s; terminating.") "Red"
            try { Start-Process taskkill.exe -ArgumentList @("/PID", $Proc.Id, "/T", "/F") -WindowStyle Hidden -Wait | Out-Null } catch { }
        }
        else {
            $ExitOk = $true
            Write-Color ("Pipeline exited (code " + $Proc.ExitCode + ").") "Gray"
        }
    }
}
catch {
    Write-Color ("[ERROR] Failed to start the pipeline: " + $_.Exception.Message) "Red"
}
finally {
    Remove-Item Env:\MULTILLM_HEADLESS, Env:\MULTILLM_RUNFOLDER, Env:\MULTILLM_PROMPT_FILE, Env:\MULTILLM_TASKS_FILE, Env:\MULTILLM_SPLITMODE, Env:\MULTILLM_WORKMODE, Env:\MULTILLM_CHEAP_JUDGE -ErrorAction SilentlyContinue
    Remove-Item Env:\MULTILLM_MODEL_OPENAI, Env:\MULTILLM_MODEL_ANTHROPIC, Env:\MULTILLM_MODEL_JUDGE -ErrorAction SilentlyContinue
}

if (-not (Test-Path -LiteralPath (Join-Path $RunFolder "task_results_summary.json"))) {
    Write-Color "[ERROR] No task_results_summary.json produced - the run may have failed (check API keys / the run folder)." "Red"
    return
}

$Rows = Get-BenchmarkRows -RunFolder $RunFolder -TaskMap $TaskMap
$Md = Write-BenchmarkReport -RunFolder $RunFolder -Rows $Rows -ModelsLine $ModelsLine
if ($OpenSummary -eq $true) { try { Start-Process notepad.exe $Md | Out-Null } catch { } }

Write-Host ""
Write-Color "Done." "Cyan"
