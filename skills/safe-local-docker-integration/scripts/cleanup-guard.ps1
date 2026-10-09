param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$ResourcesPath
)

$ErrorActionPreference = 'Stop'

function New-Finding {
    param(
        [string]$Field,
        [object]$Observed,
        [string]$Reason,
        [string]$RequiredAction
    )

    [pscustomobject]@{
        decision = 'BLOCK'
        severity = 'CRITICAL'
        source = ConvertTo-SafeSource $ResourcesPath
        field = $Field
        observed = Protect-ObservedValue $Field $Observed
        reason = $Reason
        required_action = $RequiredAction
    }
}

function ConvertTo-SafeSource {
    param([string]$Source)

    if ([string]::IsNullOrWhiteSpace($Source)) {
        return ''
    }

    return (Split-Path -Leaf $Source)
}

function Protect-ObservedValue {
    param(
        [string]$Field,
        [object]$Observed
    )

    if ($null -eq $Observed) {
        return $null
    }

    $text = if ($Observed -is [string]) { $Observed } else { $Observed | ConvertTo-Json -Compress -Depth 20 }
    $text = $text -replace '(?i)(C:\\Users\\)[^\\/:*?"<>|\s]+', '$1[REDACTED]'
    $text = $text -replace '(?i)(/Users/)[^/\s]+', '$1[REDACTED]'
    return $text
}

function Get-ObjectProperty {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Test-ManifestContainsResource {
    param(
        [object]$Manifest,
        [object]$Resource
    )

    $resources = Get-ObjectProperty $Manifest 'resources'
    $type = Get-ObjectProperty $Resource 'type'
    $id = Get-ObjectProperty $Resource 'id'

    if ($null -eq $resources -or [string]::IsNullOrWhiteSpace($type) -or [string]::IsNullOrWhiteSpace($id)) {
        return $false
    }

    $listName = switch ($type) {
        'container' { 'containers' }
        'network' { 'networks' }
        'volume' { 'volumes' }
        default { '' }
    }

    if ([string]::IsNullOrWhiteSpace($listName)) {
        return $false
    }

    $list = Get-ObjectProperty $resources $listName
    return @($list) -contains $id
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "ManifestPath not found: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ResourcesPath)) {
    throw "ResourcesPath not found: $ResourcesPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$resourcesInput = Get-Content -LiteralPath $ResourcesPath -Raw | ConvertFrom-Json
$resources = @((Get-ObjectProperty $resourcesInput 'resources'))
$findings = [System.Collections.Generic.List[object]]::new()

$runId = Get-ObjectProperty $manifest 'run_id'
$composeProject = Get-ObjectProperty $manifest 'compose_project'

if ([string]::IsNullOrWhiteSpace($runId)) {
    $findings.Add((New-Finding 'manifest.run_id' $runId 'Manifest is missing run_id.' 'Do not clean any resource until the current run id is known.')) | Out-Null
}
if ([string]::IsNullOrWhiteSpace($composeProject)) {
    $findings.Add((New-Finding 'manifest.compose_project' $composeProject 'Manifest is missing compose_project.' 'Do not clean any Docker resource until the compose project identity is known.')) | Out-Null
}

foreach ($resource in $resources) {
    $id = Get-ObjectProperty $resource 'id'
    $labels = Get-ObjectProperty $resource 'labels'
    $runLabel = Get-ObjectProperty $labels 'com.qimomoli.test-run'
    $projectLabel = Get-ObjectProperty $labels 'com.docker.compose.project'

    if (-not (Test-ManifestContainsResource $manifest $resource)) {
        $findings.Add((New-Finding "resources.$id" $id 'Resource is not listed in the manifest.' 'Do not clean this resource.')) | Out-Null
        continue
    }
    if ($runLabel -ne $runId) {
        $findings.Add((New-Finding "resources.$id.labels.com.qimomoli.test-run" $runLabel 'Resource run label does not match the manifest run id.' 'Do not clean this resource.')) | Out-Null
    }
    if ($projectLabel -ne $composeProject) {
        $findings.Add((New-Finding "resources.$id.labels.com.docker.compose.project" $projectLabel 'Resource compose project label does not match the manifest compose project.' 'Do not clean this resource.')) | Out-Null
    }
}

$decision = if ($findings.Count -gt 0) { 'BLOCK' } else { 'ALLOW' }
$result = [pscustomobject]@{
    decision = $decision
    finding_count = $findings.Count
    findings = @($findings)
}

$result | ConvertTo-Json -Depth 20
if ($decision -eq 'ALLOW') {
    exit 0
}
exit 30
