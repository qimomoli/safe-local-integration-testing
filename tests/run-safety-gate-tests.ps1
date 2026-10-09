$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$skillRoot = Join-Path $repoRoot 'skills' 'safe-local-docker-integration'
$scanner = Join-Path $skillRoot 'scripts' 'safety-gate.ps1'
$cleanupGuard = Join-Path $skillRoot 'scripts' 'cleanup-guard.ps1'
$fixtures = Join-Path $PSScriptRoot 'fixtures'
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Test failed: $Message"
    }
}

function Invoke-JsonCommand {
    param(
        [string]$Script,
        [string[]]$Arguments
    )

    $output = & $pwsh -NoProfile -File $Script @Arguments 2>&1 | Out-String
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = $output.Trim()
        Json = if ($output.Trim()) { $output | ConvertFrom-Json } else { $null }
    }
}

function Assert-GateCase {
    param(
        [string]$Fixture,
        [string]$Decision,
        [int]$ExitCode
    )

    $result = Invoke-JsonCommand -Script $scanner -Arguments @(
        '-InputPath', (Join-Path $fixtures $Fixture),
        '-RunId', 'run-001',
        '-RequireRunLabels'
    )
    Assert-True ($result.ExitCode -eq $ExitCode) "$Fixture returned exit $($result.ExitCode), expected $ExitCode. Output: $($result.Output)"
    Assert-True ($null -ne $result.Json) "$Fixture did not return JSON."
    Assert-True ($result.Json.decision -eq $Decision) "$Fixture returned decision $($result.Json.decision), expected $Decision."
}

Assert-True (Test-Path -LiteralPath $scanner) 'safety-gate.ps1 is missing.'
Assert-True (Test-Path -LiteralPath $cleanupGuard) 'cleanup-guard.ps1 is missing.'

Assert-GateCase 'allowed-local.json' 'ALLOW' 0
Assert-GateCase 'blocked-production.json' 'BLOCK' 30
Assert-GateCase 'blocked-privileged.json' 'BLOCK' 30
Assert-GateCase 'blocked-docker-socket.json' 'BLOCK' 30
Assert-GateCase 'blocked-sensitive-value.json' 'BLOCK' 30
Assert-GateCase 'blocked-unlabeled-resources.json' 'BLOCK' 30
Assert-GateCase 'ask-private-lan.json' 'ASK' 20
Assert-GateCase 'ask-object-fixed-port.json' 'ASK' 20

$sensitiveValue = Invoke-JsonCommand -Script $scanner -Arguments @(
    '-InputPath', (Join-Path $fixtures 'blocked-sensitive-value.json'),
    '-RunId', 'run-001',
    '-RequireRunLabels'
)
Assert-True ($sensitiveValue.Output -notmatch 'fixture-sensitive-value-123') 'Sensitive values were not redacted from scanner output.'
Assert-True ($sensitiveValue.Output -notmatch [regex]::Escape((Resolve-Path (Join-Path $fixtures 'blocked-sensitive-value.json')).Path)) 'Scanner output leaked the absolute fixture path.'

$missingRunId = Invoke-JsonCommand -Script $scanner -Arguments @(
    '-InputPath', (Join-Path $fixtures 'allowed-local.json'),
    '-RequireRunLabels'
)
Assert-True ($missingRunId.ExitCode -eq 30) 'Missing scanner RunId was not blocked.'
Assert-True ($missingRunId.Json.decision -eq 'BLOCK') 'Missing scanner RunId was not reported as BLOCK.'

$allowedCleanup = Invoke-JsonCommand -Script $cleanupGuard -Arguments @(
    '-ManifestPath', (Join-Path $fixtures 'cleanup-manifest.json'),
    '-ResourcesPath', (Join-Path $fixtures 'cleanup-resources-allowed.json')
)
Assert-True ($allowedCleanup.ExitCode -eq 0) "Allowed cleanup ownership returned exit $($allowedCleanup.ExitCode)."
Assert-True ($allowedCleanup.Json.decision -eq 'ALLOW') 'Allowed cleanup ownership was not ALLOW.'

$unownedCleanup = Invoke-JsonCommand -Script $cleanupGuard -Arguments @(
    '-ManifestPath', (Join-Path $fixtures 'cleanup-manifest.json'),
    '-ResourcesPath', (Join-Path $fixtures 'cleanup-resources-unowned.json')
)
Assert-True ($unownedCleanup.ExitCode -eq 30) 'Unowned cleanup resource was not blocked.'
Assert-True ($unownedCleanup.Json.decision -eq 'BLOCK') 'Unowned cleanup resource was not reported as BLOCK.'

$missingManifestRunId = Invoke-JsonCommand -Script $cleanupGuard -Arguments @(
    '-ManifestPath', (Join-Path $fixtures 'cleanup-manifest-missing-runid.json'),
    '-ResourcesPath', (Join-Path $fixtures 'cleanup-resources-allowed.json')
)
Assert-True ($missingManifestRunId.ExitCode -eq 30) 'Missing manifest RunId was not blocked.'
Assert-True ($missingManifestRunId.Json.decision -eq 'BLOCK') 'Missing manifest RunId was not reported as BLOCK.'

$missingManifestProject = Invoke-JsonCommand -Script $cleanupGuard -Arguments @(
    '-ManifestPath', (Join-Path $fixtures 'cleanup-manifest-missing-project.json'),
    '-ResourcesPath', (Join-Path $fixtures 'cleanup-resources-allowed.json')
)
Assert-True ($missingManifestProject.ExitCode -eq 30) 'Missing manifest compose project was not blocked.'
Assert-True ($missingManifestProject.Json.decision -eq 'BLOCK') 'Missing manifest compose project was not reported as BLOCK.'
Assert-True ($missingManifestProject.Output -notmatch [regex]::Escape((Resolve-Path (Join-Path $fixtures 'cleanup-resources-allowed.json')).Path)) 'Cleanup guard output leaked the absolute resources path.'

Write-Output 'Safety gate and cleanup ownership tests passed.'
