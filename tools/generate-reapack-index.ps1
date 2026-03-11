param(
    [Parameter(Mandatory = $true)]
    [string]$GithubOwner,

    [Parameter(Mandatory = $true)]
    [string]$RepoName,

    [string]$Branch = "main",
    [string]$Version = "0.1.0",
    [string]$Author,
    [string]$OutputFile = "index.xml"
)

$ErrorActionPreference = "Stop"

if (-not $Author) {
    $Author = $GithubOwner
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$actionsDir = Join-Path $repoRoot "actions"

if (-not (Test-Path $actionsDir)) {
    throw "Missing actions directory: $actionsDir"
}

$mainActionFiles = Get-ChildItem -Path $actionsDir -File -Filter "Oz Chord Track - *.lua" |
    Sort-Object Name

if (-not $mainActionFiles -or $mainActionFiles.Count -eq 0) {
    throw "No action scripts found under actions/*.lua"
}

$supportFiles = @(
    "actions/Oz Chord Track Core.lua",
    "Oz Chord Track Core.lua",
    "libs/Oz Chord Track Loader.lua",
    "libs/Oz Chord Track Core.lua",
    "libs/Oz Chord Track Snap Settings.lua",
    "libs/Oz Chord Track - Start input snap manager (experimental).lua",
    "libs/Oz Chord Track - Stop input snap manager (experimental).lua"
)

$missingSupport = $supportFiles | Where-Object {
    -not (Test-Path (Join-Path $repoRoot $_))
}

if ($missingSupport.Count -gt 0) {
    throw "Missing required support files:`n - $($missingSupport -join "`n - ")"
}

function Get-RawUrl {
    param([string]$RelativePath)

    $normalized = $RelativePath -replace "\\", "/"
    $segments = $normalized -split "/"
    $encodedPath = ($segments | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join "/"
    return "https://raw.githubusercontent.com/$GithubOwner/$RepoName/$Branch/$encodedPath"
}

function Append-SourceLine {
    param(
        [System.Text.StringBuilder]$Builder,
        [string]$RelativePath,
        [bool]$Main
    )

    $url = Get-RawUrl -RelativePath $RelativePath
    $fileAttr = [System.Security.SecurityElement]::Escape(($RelativePath -replace "\\", "/"))
    $urlEscaped = [System.Security.SecurityElement]::Escape($url)

    if ($Main) {
        [void]$Builder.AppendLine(('        <source main="main" type="script" file="{0}">{1}</source>' -f $fileAttr, $urlEscaped))
    } else {
        [void]$Builder.AppendLine(('        <source type="script" file="{0}">{1}</source>' -f $fileAttr, $urlEscaped))
    }
}

$timeStamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$website = "https://github.com/$GithubOwner/$RepoName"
$websiteEscaped = [System.Security.SecurityElement]::Escape($website)
$authorEscaped = [System.Security.SecurityElement]::Escape($Author)
$versionEscaped = [System.Security.SecurityElement]::Escape($Version)
$timeStampEscaped = [System.Security.SecurityElement]::Escape($timeStamp)

$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
[void]$sb.AppendLine('<index version="1" name="Oz Reaper Chord Track">')
[void]$sb.AppendLine('  <category name="Scripts">')
[void]$sb.AppendLine('    <reapack name="Oz Reaper Chord Track" type="script" desc="Chord Track workflow for REAPER">')
[void]$sb.AppendLine('      <metadata>')
[void]$sb.AppendLine('        <description><![CDATA[Chord Track-style workflow in REAPER with per-track follow modes, selected-track snapping, and pre/post new-note snap pipelines.]]></description>')
[void]$sb.AppendLine(('        <link rel="website">{0}</link>' -f $websiteEscaped))
[void]$sb.AppendLine('      </metadata>')
[void]$sb.AppendLine(('      <version name="{0}" author="{1}" time="{2}">' -f $versionEscaped, $authorEscaped, $timeStampEscaped))
[void]$sb.AppendLine('        <changelog><![CDATA[Initial ReaPack package.]]></changelog>')

foreach ($supportPath in $supportFiles) {
    Append-SourceLine -Builder $sb -RelativePath $supportPath -Main:$false
}

foreach ($actionFile in $mainActionFiles) {
    $relative = "actions/$($actionFile.Name)"
    Append-SourceLine -Builder $sb -RelativePath $relative -Main:$true
}

[void]$sb.AppendLine('      </version>')
[void]$sb.AppendLine('    </reapack>')
[void]$sb.AppendLine('  </category>')
[void]$sb.AppendLine('</index>')

$outputPath = Join-Path $repoRoot $OutputFile
Set-Content -Path $outputPath -Value $sb.ToString() -Encoding UTF8

Write-Output "Generated $OutputFile with $($mainActionFiles.Count) main action sources and $($supportFiles.Count) support sources."
