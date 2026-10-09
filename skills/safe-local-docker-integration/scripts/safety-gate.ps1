param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$RunId,

    [switch]$RequireRunLabels
)

$ErrorActionPreference = 'Stop'

function New-Finding {
    param(
        [string]$Decision,
        [string]$Severity,
        [string]$Source,
        [string]$Field,
        [object]$Observed,
        [string]$Reason,
        [string]$RequiredAction
    )

    [pscustomobject]@{
        decision = $Decision
        severity = $Severity
        source = ConvertTo-SafeSource $Source
        field = $Field
        observed = Protect-ObservedValue $Field $Observed
        reason = $Reason
        required_action = $RequiredAction
    }
}

function Add-Finding {
    param([object]$Finding)

    $script:findings.Add($Finding) | Out-Null
}

function ConvertTo-StringValue {
    param([object]$Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [string]) {
        return $Value
    }

    return ($Value | ConvertTo-Json -Compress -Depth 20)
}

function ConvertTo-SafeSource {
    param([string]$Source)

    if ([string]::IsNullOrWhiteSpace($Source)) {
        return ''
    }

    return (Split-Path -Leaf $Source)
}

function Test-SensitiveName {
    param([string]$Field)

    return $Field -match '(?i)(password|passwd|pwd|secret|token|api[_-]?key|access[_-]?key|private[_-]?key|credential|cert)'
}

function Test-TestCredential {
    param([object]$Value)

    $text = ConvertTo-StringValue $Value
    return $text -match '(?i)\b(dummy|test|fake|example|local|placeholder)\b'
}

function Protect-ObservedValue {
    param(
        [string]$Field,
        [object]$Observed
    )

    $text = ConvertTo-StringValue $Observed
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $Observed
    }

    if (Test-SensitiveName $Field) {
        return '[REDACTED]'
    }

    $text = $text -replace '(?i)(password|passwd|pwd|secret|token|api[_-]?key|access[_-]?key|private[_-]?key|credential|cert)(=|:)[^,\s"}]+', '$1$2[REDACTED]'
    $text = $text -replace '(?i)(C:\\Users\\)[^\\/:*?"<>|\s]+', '$1[REDACTED]'
    $text = $text -replace '(?i)(/Users/)[^/\s]+', '$1[REDACTED]'

    return $text
}

function Test-RemoteEndpoint {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $v = $Value.Trim()
    if ($v -match '(?i)\b(prod|production)\b') {
        return $true
    }
    if ($v -match '(?i)(amazonaws\.com|rds\.|aliyun|oss-|s3[.-]|cloudfront\.net|azure\.com|googleapis\.com)') {
        return $true
    }
    if ($v -match '(?i)\b[a-z0-9.-]+\.(com|net|org|io|cn|cloud|dev)(:\d+)?\b' -and $v -notmatch '(?i)(localhost|host\.docker\.internal)') {
        return $true
    }
    if ($v -match '(?<![\d.])(?:[1-9]\d?|1\d\d|2[0-1]\d|22[0-3])\.(?:\d{1,3}\.){2}\d{1,3}(?![\d.])' -and $v -notmatch '^(127|0)\.') {
        return $true
    }
    if (Test-PublicIpv6Endpoint $v) {
        return $true
    }
    return $false
}

function Test-PrivateLanEndpoint {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return $Value -match '(?<![\d.])(10\.(?:\d{1,3}\.){2}\d{1,3}|192\.168\.(?:\d{1,3}\.)\d{1,3}|172\.(1[6-9]|2\d|3[0-1])\.(?:\d{1,3}\.)\d{1,3})(?![\d.])'
}

function Get-Ipv6Candidates {
    param([string]$Value)

    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($Value, '\[([0-9a-fA-F:.%]+)\]')) {
        $candidates.Add($match.Groups[1].Value) | Out-Null
    }
    foreach ($match in [regex]::Matches($Value, '(?<![\w.])([0-9a-fA-F]{0,4}:[0-9a-fA-F:.%]+)(?![\w.])')) {
        $candidate = $match.Groups[1].Value.Trim(':')
        if ($candidate -match ':') {
            $candidates.Add($candidate) | Out-Null
        }
    }

    return @($candidates | Select-Object -Unique)
}

function Get-ParsedIpAddress {
    param([string]$Candidate)

    $ip = $null
    if ([System.Net.IPAddress]::TryParse(($Candidate -replace '%.*$', ''), [ref]$ip)) {
        return $ip
    }
    return $null
}

function Test-LocalIpv6Address {
    param([System.Net.IPAddress]$Ip)

    return [System.Net.IPAddress]::IsLoopback($Ip)
}

function Test-PrivateIpv6Endpoint {
    param([string]$Value)

    foreach ($candidate in Get-Ipv6Candidates $Value) {
        $ip = Get-ParsedIpAddress $candidate
        if ($null -eq $ip -or $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
            continue
        }

        $normalized = $ip.ToString().ToLowerInvariant()
        if (Test-LocalIpv6Address $ip) {
            continue
        }
        if ($normalized -eq '::' -or $normalized.StartsWith('fe80:') -or $normalized.StartsWith('fc') -or $normalized.StartsWith('fd')) {
            return $true
        }
    }

    return $false
}

function Test-PublicIpv6Endpoint {
    param([string]$Value)

    foreach ($candidate in Get-Ipv6Candidates $Value) {
        $ip = Get-ParsedIpAddress $candidate
        if ($null -eq $ip -or $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
            continue
        }

        if (Test-LocalIpv6Address $ip) {
            continue
        }
        if (Test-PrivateIpv6Endpoint "[$candidate]") {
            continue
        }
        return $true
    }

    return $false
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

function Test-HasLabel {
    param(
        [object]$Service,
        [string]$ExpectedRunId
    )

    $labels = Get-ObjectProperty $Service 'labels'
    if ($null -eq $labels) {
        return $false
    }

    if ($labels -is [array]) {
        return ($labels -contains "com.qimomoli.test-run=$ExpectedRunId")
    }

    $labelValue = Get-ObjectProperty $labels 'com.qimomoli.test-run'
    return ($labelValue -eq $ExpectedRunId)
}

function Inspect-Scalar {
    param(
        [string]$Field,
        [object]$Value,
        [string]$Source = $InputPath
    )

    $text = ConvertTo-StringValue $Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return
    }

    if ((Test-SensitiveName $Field) -and -not (Test-TestCredential $Value)) {
        Add-Finding (New-Finding 'BLOCK' 'CRITICAL' $Source $Field $Value 'Generated runtime config contains a credential-like value that is not clearly dummy or test-only.' 'Replace with a dummy local credential and keep secret values out of rendered output.')
        return
    }

    if ((Test-PrivateLanEndpoint $text) -or (Test-PrivateIpv6Endpoint $text)) {
        Add-Finding (New-Finding 'ASK' 'HIGH' $Source $Field $text 'Private LAN endpoints are not local by default.' 'Get explicit approval for the exact target or replace with a local mock.')
        return
    }

    if (Test-RemoteEndpoint $text) {
        Add-Finding (New-Finding 'BLOCK' 'CRITICAL' $Source $Field $text 'Generated runtime config references a public, production, or remote endpoint.' 'Replace with a local service, mock, or explicitly approved test endpoint.')
    }
}

function Resolve-EnvFilePath {
    param(
        [string]$EnvFile,
        [string]$BaseDirectory
    )

    if ([string]::IsNullOrWhiteSpace($EnvFile)) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($EnvFile)) {
        return [System.IO.Path]::GetFullPath($EnvFile)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BaseDirectory $EnvFile))
}

function Test-IsPathUnderDirectory {
    param(
        [string]$Path,
        [string]$Directory
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $fullDirectory = [System.IO.Path]::GetFullPath($Directory).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $fullPath.StartsWith($fullDirectory + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.Equals($fullDirectory, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-EnvFilePathFromEntry {
    param([object]$Entry)

    if ($Entry -is [string]) {
        return $Entry
    }
    return ConvertTo-StringValue (Get-ObjectProperty $Entry 'path')
}

function Inspect-EnvFile {
    param(
        [string]$Field,
        [object]$EnvFile,
        [string]$BaseDirectory
    )

    $envFileText = Get-EnvFilePathFromEntry $EnvFile
    Inspect-Scalar $Field $envFileText
    if ([string]::IsNullOrWhiteSpace($envFileText)) {
        return
    }

    $resolvedPath = Resolve-EnvFilePath $envFileText $BaseDirectory
    if (-not (Test-IsPathUnderDirectory $resolvedPath $BaseDirectory)) {
        Add-Finding (New-Finding 'BLOCK' 'HIGH' $InputPath $Field $envFileText 'env_file points outside the rendered config directory.' 'Keep env files inside the generated test workspace and re-render the config.')
        return
    }
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        Add-Finding (New-Finding 'BLOCK' 'HIGH' $InputPath $Field $envFileText 'env_file was referenced but could not be read.' 'Render or copy the test-only env file into the generated test workspace before scanning.')
        return
    }

    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $resolvedPath) {
        $lineNumber++
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $assignment = $trimmed -replace '^(?i)export\s+', ''
        $separator = $assignment.IndexOf('=')
        if ($separator -lt 1) {
            continue
        }

        $key = $assignment.Substring(0, $separator).Trim()
        $value = $assignment.Substring($separator + 1).Trim().Trim('"').Trim("'")
        Inspect-Scalar "$Field.$key" $value $resolvedPath
    }
}

function Inspect-Volume {
    param(
        [string]$Field,
        [object]$Volume
    )

    $text = ConvertTo-StringValue $Volume
    if ([string]::IsNullOrWhiteSpace($text)) {
        return
    }

    if ($text -match '(?i)(/var/run/docker\.sock|//var/run/docker\.sock|docker_engine|dockerDesktopLinuxEngine)') {
        Add-Finding (New-Finding 'BLOCK' 'CRITICAL' $InputPath $Field $text 'Docker socket mounts expose host Docker control.' 'Remove the Docker socket mount.')
    }

    if ($text -match '(^|:)(/|/proc|/sys|/root|/home|C:\\|C:/)(:|$)') {
        Add-Finding (New-Finding 'BLOCK' 'CRITICAL' $InputPath $Field $text 'Broad or sensitive host path mount is not allowed for a generic local test.' 'Mount only a generated test workspace path.')
    }

    foreach ($volumeField in @('type', 'source', 'target', 'read_only', 'consistency', 'bind', 'volume')) {
        Inspect-Scalar "$Field.$volumeField" (Get-ObjectProperty $Volume $volumeField)
    }
}

function Inspect-OwnedResource {
    param(
        [string]$Kind,
        [string]$Name,
        [object]$Resource
    )

    if (-not $RequireRunLabels -or [string]::IsNullOrWhiteSpace($RunId)) {
        return
    }

    if (-not (Test-HasLabel $Resource $RunId)) {
        Add-Finding (New-Finding 'BLOCK' 'HIGH' $InputPath "$Kind.$Name.labels" $null "Top-level $Kind resource does not carry the current run ownership label." "Add com.qimomoli.test-run=$RunId or remove the shared resource from this test run.")
    }
}

function Inspect-Port {
    param(
        [string]$Field,
        [object]$Port
    )

    $portText = ConvertTo-StringValue $Port
    if ([string]::IsNullOrWhiteSpace($portText)) {
        return
    }

    if ($portText -match '^(0\.0\.0\.0:)?\d+:\d+' -or $portText -match '^\d+:\d+') {
        Add-Finding (New-Finding 'ASK' 'WARN' $InputPath $Field $Port 'Fixed or broadly bound host ports may collide with another run or expose services.' 'Use dynamically allocated localhost ports or document the explicit approval.')
        return
    }
    if ($portText -match '^(?:[A-Za-z0-9_.-]+:)?\d+:\d+(?:/(tcp|udp))?$' -or $portText -match '^\[[^\]]+\]:\d+:\d+(?:/(tcp|udp))?$') {
        Add-Finding (New-Finding 'ASK' 'WARN' $InputPath $Field $Port 'Fixed or broadly bound host ports may collide with another run or expose services.' 'Use dynamically allocated localhost ports or document the explicit approval.')
        return
    }

    $published = Get-ObjectProperty $Port 'published'
    $hostIp = ConvertTo-StringValue (Get-ObjectProperty $Port 'host_ip')
    if ($null -ne $published -or $hostIp -match '^(0\.0\.0\.0|::)$') {
        Add-Finding (New-Finding 'ASK' 'WARN' $InputPath $Field $Port 'Fixed or broadly bound host ports may collide with another run or expose services.' 'Use dynamically allocated localhost ports or document the explicit approval.')
    }
    if ((ConvertTo-StringValue (Get-ObjectProperty $Port 'mode')) -match '(?i)^host$') {
        Add-Finding (New-Finding 'ASK' 'WARN' $InputPath "$Field.mode" (Get-ObjectProperty $Port 'mode') 'Port uses host publish mode.' 'Use isolated dynamic localhost ports or document the explicit approval.')
    }
    foreach ($portField in @('host_ip', 'mode', 'protocol', 'name', 'app_protocol', 'target', 'published')) {
        Inspect-Scalar "$Field.$portField" (Get-ObjectProperty $Port $portField)
    }
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "InputPath not found: $InputPath"
}

$script:findings = [System.Collections.Generic.List[object]]::new()
$config = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
$services = Get-ObjectProperty $config 'services'
$inputDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($InputPath))

if ($RequireRunLabels -and [string]::IsNullOrWhiteSpace($RunId)) {
    Add-Finding (New-Finding 'BLOCK' 'HIGH' $InputPath 'RunId' $RunId 'Run label validation was requested but no RunId was provided.' 'Pass -RunId for the current environment.')
}

if ($null -eq $services) {
    Add-Finding (New-Finding 'BLOCK' 'HIGH' $InputPath 'services' $null 'Compose config has no services object.' 'Provide rendered compose JSON with services.')
}

foreach ($serviceProperty in @($services.PSObject.Properties)) {
    $serviceName = $serviceProperty.Name
    $service = $serviceProperty.Value
    $prefix = "services.$serviceName"

    foreach ($setting in @('privileged')) {
        $value = Get-ObjectProperty $service $setting
        if ($value -eq $true) {
            Add-Finding (New-Finding 'BLOCK' 'CRITICAL' $InputPath "$prefix.$setting" $value "$setting is not allowed." "Remove $setting or isolate it behind an explicit approved test policy.")
        }
    }

    foreach ($setting in @('network_mode', 'pid', 'ipc')) {
        $value = Get-ObjectProperty $service $setting
        if ((ConvertTo-StringValue $value) -match '(?i)^host$') {
            Add-Finding (New-Finding 'BLOCK' 'CRITICAL' $InputPath "$prefix.$setting" $value "$setting uses the host namespace." "Remove host namespace usage.")
        }
    }

    foreach ($setting in @('cap_add', 'devices', 'security_opt')) {
        $value = Get-ObjectProperty $service $setting
        if ($null -ne $value -and (ConvertTo-StringValue $value).Length -gt 2) {
            Add-Finding (New-Finding 'BLOCK' 'HIGH' $InputPath "$prefix.$setting" $value "$setting grants elevated host/container privileges." "Remove it or require explicit approval for the exact target.")
        }
    }

    $image = ConvertTo-StringValue (Get-ObjectProperty $service 'image')
    if ($image -match '(?i)(prod|production|release)') {
        Add-Finding (New-Finding 'BLOCK' 'HIGH' $InputPath "$prefix.image" $image 'A service image appears to use a production/release tag.' 'Use a local test image or explicitly approved dependency image.')
    }

    if ($RequireRunLabels -and -not [string]::IsNullOrWhiteSpace($RunId) -and -not (Test-HasLabel $service $RunId)) {
        Add-Finding (New-Finding 'BLOCK' 'HIGH' $InputPath "$prefix.labels" $null 'Service does not carry the current run ownership label.' "Add com.qimomoli.test-run=$RunId.")
    }

    $environment = Get-ObjectProperty $service 'environment'
    if ($null -ne $environment) {
        if ($environment -is [array]) {
            for ($i = 0; $i -lt $environment.Count; $i++) {
                Inspect-Scalar "$prefix.environment[$i]" $environment[$i]
            }
        } else {
            foreach ($envProperty in @($environment.PSObject.Properties)) {
                Inspect-Scalar "$prefix.environment.$($envProperty.Name)" $envProperty.Value
            }
        }
    }

    foreach ($field in @('command', 'entrypoint', 'extra_hosts', 'dns', 'healthcheck', 'logging', 'sysctls', 'ulimits', 'secrets', 'configs')) {
        Inspect-Scalar "$prefix.$field" (Get-ObjectProperty $service $field)
    }

    $envFiles = @(Get-ObjectProperty $service 'env_file')
    if ($null -ne $envFiles -and $envFiles.Count -gt 0) {
        for ($i = 0; $i -lt $envFiles.Count; $i++) {
            Inspect-EnvFile "$prefix.env_file[$i]" $envFiles[$i] $inputDirectory
        }
    }

    $volumes = @(Get-ObjectProperty $service 'volumes')
    if ($null -ne $volumes -and $volumes.Count -gt 0) {
        for ($i = 0; $i -lt $volumes.Count; $i++) {
            Inspect-Volume "$prefix.volumes[$i]" $volumes[$i]
        }
    }

    $ports = @(Get-ObjectProperty $service 'ports')
    if ($null -ne $ports -and $ports.Count -gt 0) {
        for ($i = 0; $i -lt $ports.Count; $i++) {
            Inspect-Port "$prefix.ports[$i]" $ports[$i]
        }
    }
}

$networksProperty = $config.PSObject.Properties['networks']
if ($null -ne $networksProperty -and $null -ne $networksProperty.Value) {
    foreach ($networkProperty in @($networksProperty.Value.PSObject.Properties)) {
        Inspect-OwnedResource 'networks' $networkProperty.Name $networkProperty.Value
    }
}

$volumesProperty = $config.PSObject.Properties['volumes']
if ($null -ne $volumesProperty -and $null -ne $volumesProperty.Value) {
    foreach ($volumeProperty in @($volumesProperty.Value.PSObject.Properties)) {
        Inspect-OwnedResource 'volumes' $volumeProperty.Name $volumeProperty.Value
    }
}

$decisionRank = @{
    'ALLOW' = 0
    'REPLACE' = 10
    'ASK' = 20
    'BLOCK' = 30
}

$decision = 'ALLOW'
foreach ($finding in $findings) {
    if ($decisionRank[$finding.decision] -gt $decisionRank[$decision]) {
        $decision = $finding.decision
    }
}

$result = [pscustomobject]@{
    decision = $decision
    finding_count = $findings.Count
    findings = @($findings)
}

$result | ConvertTo-Json -Depth 20
exit $decisionRank[$decision]
