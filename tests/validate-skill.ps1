$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$skillRoot = Join-Path $repoRoot 'skills' 'safe-local-docker-integration'
$skillPath = Join-Path $skillRoot 'SKILL.md'
$gatePath = Join-Path $skillRoot 'references' 'safety-gate.md'
$manifestPath = Join-Path $skillRoot 'references' 'environment-manifest.md'
$reportPath = Join-Path $skillRoot 'references' 'report-template.md'
$scannerPath = Join-Path $skillRoot 'scripts' 'safety-gate.ps1'
$cleanupGuardPath = Join-Path $skillRoot 'scripts' 'cleanup-guard.ps1'
$openaiYamlPath = Join-Path $skillRoot 'agents' 'openai.yaml'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Validation failed: $Message"
    }
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Message
    )

    Assert-True ($Text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) $Message
}

Assert-True (Test-Path -LiteralPath $skillPath) 'SKILL.md is missing.'
Assert-True (Test-Path -LiteralPath $gatePath) 'safety-gate.md is missing.'
Assert-True (Test-Path -LiteralPath $manifestPath) 'environment-manifest.md is missing.'
Assert-True (Test-Path -LiteralPath $reportPath) 'report-template.md is missing.'
Assert-True (Test-Path -LiteralPath $scannerPath) 'safety-gate.ps1 is missing.'
Assert-True (Test-Path -LiteralPath $cleanupGuardPath) 'cleanup-guard.ps1 is missing.'
Assert-True (Test-Path -LiteralPath $openaiYamlPath) 'agents/openai.yaml is missing.'

$skill = Get-Content -LiteralPath $skillPath -Raw
$gate = Get-Content -LiteralPath $gatePath -Raw
$manifest = Get-Content -LiteralPath $manifestPath -Raw
$report = Get-Content -LiteralPath $reportPath -Raw
$scanner = Get-Content -LiteralPath $scannerPath -Raw
$cleanupGuard = Get-Content -LiteralPath $cleanupGuardPath -Raw

Assert-Contains $skill 'docker context show' 'SKILL.md must require a local Docker context preflight.'
Assert-Contains $skill 'DOCKER_HOST' 'SKILL.md must require a DOCKER_HOST preflight.'
Assert-Contains $skill 'PREFLIGHT' 'SKILL.md must define explicit execution phases.'
Assert-Contains $skill 'diagnostic bundle' 'SKILL.md must define failure evidence retention.'
Assert-Contains $skill 'environment-manifest.md' 'SKILL.md must reference the environment manifest.'
Assert-Contains $skill 'confirm-before-work' 'SKILL.md must integrate file-write confirmation boundaries.'
Assert-Contains $skill 'name: safe-local-docker-integration' 'SKILL.md frontmatter must match the installable skill folder.'
Assert-Contains $skill 'END_TO_END' 'SKILL.md must require end-to-end coverage for the changed behavior.'
Assert-Contains $skill 'real entry point' 'SKILL.md must identify the real entry point of the changed behavior.'
Assert-Contains $skill 'real exit' 'SKILL.md must verify the real observable exit of the changed behavior.'
Assert-Contains $skill 'mock cannot replace' 'SKILL.md must prevent mocks from replacing the changed integration path.'
Assert-Contains $skill 'partial' 'SKILL.md must classify incomplete end-to-end coverage as partial.'

Assert-Contains $gate 'com.qimomoli.test-run' 'Safety gate must require resource ownership labels.'
Assert-Contains $gate 'pid: host' 'Safety gate must block host PID namespaces.'
Assert-Contains $gate 'ipc: host' 'Safety gate must block host IPC namespaces.'
Assert-Contains $gate 'cap_add' 'Safety gate must address added Linux capabilities.'
Assert-Contains $gate 'decision: ALLOW | REPLACE | BLOCK | ASK' 'Safety gate must define a uniform decision protocol.'
Assert-Contains $gate 'host.docker.internal' 'Safety gate must define the host callback restriction.'
Assert-Contains $gate 'private LAN' 'Safety gate must define the private LAN policy.'
Assert-Contains $gate 'scripts/safety-gate.ps1' 'Safety gate must reference the automated scanner.'
Assert-Contains $gate 'scripts/cleanup-guard.ps1' 'Safety gate must reference the cleanup guard.'
Assert-Contains $gate 'cross-service' 'Safety gate must require cross-service evidence for changed integration paths.'
Assert-Contains $gate 'real protocol' 'Safety gate must require real protocols at changed service boundaries.'
Assert-Contains $gate 'single-service' 'Safety gate must distinguish single-service checks from integration evidence.'

Assert-Contains $manifest 'run_id' 'Environment manifest must identify the run.'
Assert-Contains $manifest 'com.qimomoli.test-run' 'Environment manifest must define the resource label.'
Assert-Contains $manifest 'cleanup_owner' 'Environment manifest must define cleanup ownership.'

Assert-Contains $report 'Verdict' 'Report template must provide a verdict.'
Assert-Contains $report 'Safety gate' 'Report template must summarize the safety gate.'
Assert-Contains $report 'Preserved evidence' 'Report template must report retained evidence.'
Assert-Contains $report 'Coverage path' 'Report template must record the end-to-end coverage path.'
Assert-Contains $report 'real service boundaries' 'Report template must record real service boundaries.'
Assert-Contains $report 'mock or stub' 'Report template must disclose mock or stub usage.'

Assert-Contains $scanner 'Protect-ObservedValue' 'Safety scanner must redact sensitive observed values.'
Assert-Contains $scanner 'networks' 'Safety scanner must inspect top-level network ownership.'
Assert-Contains $scanner 'volumes' 'Safety scanner must inspect top-level volume ownership.'
Assert-Contains $cleanupGuard 'manifest.compose_project' 'Cleanup guard must block missing compose project identity.'

Write-Output 'Skill validation passed.'
