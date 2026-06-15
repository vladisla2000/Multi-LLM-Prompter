cls
# ============================================================
# Validate-MultiLLM.ps1
# Version: v0.1
# Purpose: Local pre-delivery validation harness for Multi-LLM Prompter.
#   Codifies the skill's "validate-before-delivery" checklist and adds
#   behavioral tests of the frozen pure functions (cost + routing).
# PowerShell: 5.1 / ISE friendly. ASCII source, UTF-8 BOM, CRLF.
#
# What it does (no API calls, no GUI launch):
#   A. STATIC  - parse (0 errors), BOM, cls-first, ASCII-only body, CRLF,
#                here-string balance, no top-level param(), Add_Click count.
#                Run for the main app AND the run-review helper.
#   B. INVARIANTS - the main app still contains the load-bearing contracts:
#                the 3 judge markers, the frozen function names, and the
#                Full->strong-judge enforcement line.
#   C. BEHAVIOR - AST-extracts every function definition from the main app
#                (top-level GUI code is NOT run), stubs the few script globals
#                they need, and asserts golden cases for Get-EstimatedCostUsd,
#                Get-TaskType, Get-TaskWorkMode, and Split-UserPromptIntoTasks.
#
# Exit code 0 = all checks passed (warnings allowed); 1 = at least one FAIL.
# ============================================================

# -----------------------------
# USER PARAMETERS - EDIT HERE (auto-detected by default)
# -----------------------------

$ProjectRoot = ""        # empty => folder this script sits in
$MainScriptPath = ""     # empty => newest Multi-LLM-Prompter-v*.ps1 in $ProjectRoot
$HelperScriptPath = ""   # empty => newest Multi-LLM-RunReviewHelper-v*.ps1 in $ProjectRoot\add

# -----------------------------
# INFRASTRUCTURE
# -----------------------------

$Script:Results = @()

function Add-Result {
    param(
        [string]$Section,
        [string]$Name,
        [string]$Status,   # PASS / FAIL / WARN / INFO
        [string]$Detail = ""
    )
    $Script:Results += [pscustomobject]@{
        Section = $Section
        Name    = $Name
        Status  = $Status
        Detail  = $Detail
    }
}

function Assert-That {
    param(
        [string]$Section,
        [string]$Name,
        [bool]$Condition,
        [string]$Detail = ""
    )
    if ($Condition) {
        Add-Result -Section $Section -Name $Name -Status "PASS" -Detail $Detail
    }
    else {
        Add-Result -Section $Section -Name $Name -Status "FAIL" -Detail $Detail
    }
}

function Resolve-ScriptFolder {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { return $PSScriptRoot }
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) { return (Split-Path -Path $PSCommandPath -Parent) }
    if ($null -ne $MyInvocation.MyCommand.Path) { return (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) }
    return (Get-Location).Path
}

function Get-NewestByVersion {
    param(
        [string]$Folder,
        [string]$Filter
    )
    if (-not (Test-Path -LiteralPath $Folder)) { return $null }
    $Files = @(Get-ChildItem -LiteralPath $Folder -Filter $Filter -File -ErrorAction SilentlyContinue)
    if ($Files.Count -eq 0) { return $null }
    # Sort by the numeric version embedded in the name. Handles any component count:
    # v0.1 / v0.2 (2-part helper) and v0_8_52 / v0.8.52 (3-part app) alike.
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

# -----------------------------
# A. STATIC FILE CHECKS
# -----------------------------

function Invoke-StaticChecks {
    param(
        [string]$Label,
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Add-Result -Section $Label -Name "file exists" -Status "FAIL" -Detail $Path
        return
    }

    # Parse (0 errors). Also returns the AST for downstream checks.
    $Tokens = $null; $Errors = $null
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$Errors)
    Assert-That -Section $Label -Name "parses with 0 errors" -Condition ($Errors.Count -eq 0) -Detail ("errors=" + $Errors.Count)
    if ($Errors.Count -gt 0) {
        foreach ($E in ($Errors | Select-Object -First 5)) {
            Add-Result -Section $Label -Name "parse error" -Status "INFO" -Detail ("L" + $E.Extent.StartLineNumber + ": " + $E.Message)
        }
    }

    $Bytes = [System.IO.File]::ReadAllBytes($Path)
    $HasBom = ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF)
    Assert-That -Section $Label -Name "UTF-8 BOM present" -Condition $HasBom

    # ASCII-only body (skip the 3 BOM bytes).
    $NonAscii = 0
    for ($i = 3; $i -lt $Bytes.Length; $i++) { if ($Bytes[$i] -gt 0x7F) { $NonAscii++ } }
    Assert-That -Section $Label -Name "ASCII-only body (0 non-ASCII bytes)" -Condition ($NonAscii -eq 0) -Detail ("nonAscii=" + $NonAscii)

    $Text = [System.IO.File]::ReadAllText($Path)
    $BareLf = ([regex]::Matches($Text, "(?<!`r)`n")).Count
    Assert-That -Section $Label -Name "CRLF line endings (0 bare LF)" -Condition ($BareLf -eq 0) -Detail ("bareLF=" + $BareLf)

    $FirstLine = (Get-Content -LiteralPath $Path -TotalCount 1)
    Assert-That -Section $Label -Name "cls is the first line" -Condition ($FirstLine -eq "cls") -Detail ("first='" + $FirstLine + "'")

    $Open = ([regex]::Matches($Text, '@"')).Count
    $Close = ([regex]::Matches($Text, '"@')).Count
    Assert-That -Section $Label -Name "here-strings balanced (@"" == ""@)" -Condition ($Open -eq $Close) -Detail ("open=" + $Open + " close=" + $Close)

    # No top-level param() (user convention).
    $HasTopParam = ($null -ne $Ast.ParamBlock)
    Assert-That -Section $Label -Name "no top-level param() block" -Condition (-not $HasTopParam)

    # Add_Click count is informational (changes per version).
    $ClickCount = ([regex]::Matches($Text, 'Add_Click')).Count
    Add-Result -Section $Label -Name "Add_Click handlers" -Status "INFO" -Detail ("count=" + $ClickCount)

    $FuncCount = ([regex]::Matches($Text, '(?m)^\s*function\s+')).Count
    Add-Result -Section $Label -Name "function definitions" -Status "INFO" -Detail ("count=" + $FuncCount)
}

# -----------------------------
# B. INVARIANT CHECKS (main app)
# -----------------------------

function Invoke-InvariantChecks {
    param([string]$Path)

    $Label = "INVARIANTS"
    $Text = [System.IO.File]::ReadAllText($Path)

    foreach ($Marker in "---JUDGE_JSON---", "---FINAL_ANSWER_MARKDOWN---", "---IMPROVED_PROMPT---") {
        Assert-That -Section $Label -Name ("judge marker present: " + $Marker) -Condition ($Text.Contains($Marker))
    }

    foreach ($Fn in "Get-TaskType", "Get-TaskWorkMode", "Get-EstimatedCostUsd", "Get-RouterDecision", "Split-UserPromptIntoTasks") {
        $Defined = ([regex]::IsMatch($Text, "(?m)^function\s+" + [regex]::Escape($Fn) + "\b"))
        Assert-That -Section $Label -Name ("frozen function defined: " + $Fn) -Condition $Defined
    }

    # Full -> strong judge enforcement must still be wired.
    $StrongOk = ([regex]::IsMatch($Text, 'JudgeMode\s*-eq\s*"Full"') -and $Text.Contains('AnthropicModel_JudgeStrong'))
    Assert-That -Section $Label -Name "Full->strong-judge enforcement present" -Condition $StrongOk
}

# -----------------------------
# C. BEHAVIORAL CHECKS (extract functions, assert)
# -----------------------------

function Invoke-BehaviorChecks {
    param([string]$Path)

    $Label = "BEHAVIOR"

    $Tokens = $null; $Errors = $null
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$Errors)
    if ($Errors.Count -gt 0) {
        Add-Result -Section $Label -Name "extract functions" -Status "FAIL" -Detail "main script has parse errors; skipping behavior tests"
        return
    }

    # Pull EVERY function definition (top-level GUI code is excluded by construction).
    $FuncAsts = $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    $Defs = ($FuncAsts | ForEach-Object { $_.Extent.Text }) -join ("`r`n`r`n")

    try {
        . ([scriptblock]::Create($Defs))
    }
    catch {
        Add-Result -Section $Label -Name "define extracted functions" -Status "FAIL" -Detail $_.Exception.Message
        return
    }
    Add-Result -Section $Label -Name "define extracted functions" -Status "INFO" -Detail ("functions=" + $FuncAsts.Count)

    # --- Stub the script globals the functions read ---
    $Script:MultiLLMConfig = [pscustomobject]@{
        CostPer1MTokens = [pscustomobject]@{
            "Anthropic|claude-opus-4-8" = [pscustomobject]@{ InputUsd = 5.0;  OutputUsd = 25.0 }
            "OpenAI|gpt-4.1-mini"       = [pscustomobject]@{ InputUsd = 0.4;  OutputUsd = 1.6  }
        }
    }
    $CodeTriggersOverrideDocumentation = $false
    $SimplePromptMaxChars = 200

    # --- Get-EstimatedCostUsd: golden math (from HANDOFF live validation) ---
    $C1 = Get-EstimatedCostUsd -Provider "Anthropic" -Model "claude-opus-4-8" -InputTokens 3664 -OutputTokens 2187
    Assert-That -Section $Label -Name "cost: Opus 3664in/2187out = 0.072995" -Condition ($C1 -eq 0.072995) -Detail ("got=" + $C1)

    $C2 = Get-EstimatedCostUsd -Provider "OpenAI" -Model "gpt-4.1-mini" -InputTokens 1000000 -OutputTokens 0
    Assert-That -Section $Label -Name "cost: 1M input @0.4 = 0.4" -Condition ($C2 -eq 0.4) -Detail ("got=" + $C2)

    $C3 = Get-EstimatedCostUsd -Provider "Nobody" -Model "ghost-1" -InputTokens 100 -OutputTokens 100
    Assert-That -Section $Label -Name "cost: unknown model => null (reported, not silent 0)" -Condition ($null -eq $C3) -Detail ("got=" + $C3)

    # --- Get-TaskType: classification ---
    $TT1 = Get-TaskType -PromptText "write a poem about the sea"
    Assert-That -Section $Label -Name "type: poem => creative" -Condition ($TT1 -eq "creative") -Detail ("got=" + $TT1)

    $TT2 = Get-TaskType -PromptText "hi there"
    Assert-That -Section $Label -Name "type: greeting => simple" -Condition ($TT2 -eq "simple") -Detail ("got=" + $TT2)

    $TT3 = Get-TaskType -PromptText "create a powershell script for active directory"
    Assert-That -Section $Label -Name "type: create AD script => code" -Condition ($TT3 -eq "code") -Detail ("got=" + $TT3)

    $TT4 = Get-TaskType -PromptText "build a wpf datagrid gui in powershell"
    Assert-That -Section $Label -Name "type: wpf gui => ui_code" -Condition ($TT4 -eq "ui_code") -Detail ("got=" + $TT4)

    $ValidTypes = @("simple", "technical", "code", "ui_code", "documentation", "creative")
    $TT5 = Get-TaskType -PromptText "summarize this management guide"
    Assert-That -Section $Label -Name "type: returns a valid type (contract)" -Condition ($ValidTypes -contains $TT5) -Detail ("got=" + $TT5)

    # --- Get-TaskWorkMode: explicit override + Auto rules ---
    $TaskWorkMode = "Review"
    $UiCodeAutoWorkMode = "Review"
    $WM1 = Get-TaskWorkMode -PromptText "anything at all" -TaskType "code"
    Assert-That -Section $Label -Name "workmode: explicit Review overrides Auto" -Condition ($WM1 -eq "Review") -Detail ("got=" + $WM1)

    $TaskWorkMode = "Script"
    $WM2 = Get-TaskWorkMode -PromptText "anything at all" -TaskType "creative"
    Assert-That -Section $Label -Name "workmode: explicit Script overrides Auto" -Condition ($WM2 -eq "Script") -Detail ("got=" + $WM2)

    # Auto from here on.
    $TaskWorkMode = "Auto"
    $UiCodeAutoWorkMode = "Review"

    $WM3 = Get-TaskWorkMode -PromptText "explain the bug and propose a safe correction" -TaskType "technical"
    Assert-That -Section $Label -Name "workmode: technical+correction => Script (v0.8.52 ordering)" -Condition ($WM3 -eq "Script") -Detail ("got=" + $WM3)

    $WM4 = Get-TaskWorkMode -PromptText "review and analyze this design" -TaskType "technical"
    Assert-That -Section $Label -Name "workmode: technical+review => Review" -Condition ($WM4 -eq "Review") -Detail ("got=" + $WM4)

    $WM5 = Get-TaskWorkMode -PromptText "create a script that lists users" -TaskType "code"
    Assert-That -Section $Label -Name "workmode: code+script => Script" -Condition ($WM5 -eq "Script") -Detail ("got=" + $WM5)

    $WM6 = Get-TaskWorkMode -PromptText "tell me a story" -TaskType "creative"
    Assert-That -Section $Label -Name "workmode: creative => Review" -Condition ($WM6 -eq "Review") -Detail ("got=" + $WM6)

    # --- Split-UserPromptIntoTasks ---
    $S1 = @(Split-UserPromptIntoTasks -PromptText "do exactly one thing" -Mode "None" -MaxTasks 10)
    Assert-That -Section $Label -Name "split: Mode None => 1 task, WasSplit false" -Condition ($S1.Count -eq 1 -and $S1[0].WasSplit -eq $false) -Detail ("count=" + $S1.Count)

    $S2 = @(Split-UserPromptIntoTasks -PromptText "" -Mode "Heuristic" -MaxTasks 10)
    Assert-That -Section $Label -Name "split: empty prompt => 1 task" -Condition ($S2.Count -eq 1) -Detail ("count=" + $S2.Count)

    $S3 = @(Split-UserPromptIntoTasks -PromptText "just a single line request" -Mode "Heuristic" -MaxTasks 10)
    Assert-That -Section $Label -Name "split: single line => 1 task" -Condition ($S3.Count -eq 1) -Detail ("count=" + $S3.Count)

    $HasFields = ($S1.Count -gt 0 -and ($S1[0].PSObject.Properties.Name -contains "TaskId") -and ($S1[0].PSObject.Properties.Name -contains "PromptText"))
    Assert-That -Section $Label -Name "split: task objects carry TaskId+PromptText (contract)" -Condition $HasFields
}

# -----------------------------
# MAIN
# -----------------------------

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Multi-LLM Prompter - Validation Harness v0.1" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = Resolve-ScriptFolder }
if ([string]::IsNullOrWhiteSpace($MainScriptPath)) { $MainScriptPath = Get-NewestByVersion -Folder $ProjectRoot -Filter "Multi-LLM-Prompter-v*.ps1" }
if ([string]::IsNullOrWhiteSpace($HelperScriptPath)) { $HelperScriptPath = Get-NewestByVersion -Folder (Join-Path $ProjectRoot "add") -Filter "Multi-LLM-RunReviewHelper-v*.ps1" }

Write-Host ("Project root : " + $ProjectRoot) -ForegroundColor Gray
Write-Host ("Main script  : " + $MainScriptPath) -ForegroundColor Gray
Write-Host ("Helper script: " + $HelperScriptPath) -ForegroundColor Gray

if ([string]::IsNullOrWhiteSpace($MainScriptPath) -or -not (Test-Path -LiteralPath $MainScriptPath)) {
    Write-Host "[ERROR] Could not locate the main Multi-LLM-Prompter-v*.ps1. Set `$MainScriptPath." -ForegroundColor Red
    return
}

Invoke-StaticChecks -Label "STATIC: main app" -Path $MainScriptPath
if (-not [string]::IsNullOrWhiteSpace($HelperScriptPath) -and (Test-Path -LiteralPath $HelperScriptPath)) {
    Invoke-StaticChecks -Label "STATIC: helper" -Path $HelperScriptPath
}
else {
    Add-Result -Section "STATIC: helper" -Name "helper located" -Status "WARN" -Detail "No RunReviewHelper found under add\"
}
Invoke-InvariantChecks -Path $MainScriptPath
Invoke-BehaviorChecks -Path $MainScriptPath

# -----------------------------
# REPORT
# -----------------------------

$Fail = @($Script:Results | Where-Object { $_.Status -eq "FAIL" }).Count
$Pass = @($Script:Results | Where-Object { $_.Status -eq "PASS" }).Count
$Warn = @($Script:Results | Where-Object { $_.Status -eq "WARN" }).Count
$Info = @($Script:Results | Where-Object { $_.Status -eq "INFO" }).Count

Write-Host ""
$LastSection = ""
foreach ($R in $Script:Results) {
    if ($R.Section -ne $LastSection) {
        Write-Host ""
        Write-Host ("--- " + $R.Section + " ---") -ForegroundColor Cyan
        $LastSection = $R.Section
    }
    $Color = "Gray"
    if ($R.Status -eq "PASS") { $Color = "Green" }
    elseif ($R.Status -eq "FAIL") { $Color = "Red" }
    elseif ($R.Status -eq "WARN") { $Color = "Yellow" }
    $Line = "[" + $R.Status + "] " + $R.Name
    if (-not [string]::IsNullOrWhiteSpace($R.Detail)) { $Line = $Line + "  (" + $R.Detail + ")" }
    Write-Host $Line -ForegroundColor $Color
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
$Overall = "PASS"
$OverallColor = "Green"
if ($Fail -gt 0) { $Overall = "FAIL"; $OverallColor = "Red" }
Write-Host ("Overall: " + $Overall + "   PASS=" + $Pass + "  FAIL=" + $Fail + "  WARN=" + $Warn + "  INFO=" + $Info) -ForegroundColor $OverallColor
Write-Host "============================================================" -ForegroundColor Cyan

if ($Fail -gt 0) { exit 1 }
