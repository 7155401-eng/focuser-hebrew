# Focuser Hebrew - Windows PowerShell 5.1 installer
# This does not overwrite the official Focuser installation.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = '7155401-eng/focuser-hebrew'
$workflow = 'build-hebrew-windows.yml'
$target = Join-Path $env:LOCALAPPDATA 'Programs\Focuser-Hebrew'
$work = Join-Path $env:TEMP ('Focuser-Hebrew-' + [Guid]::NewGuid().ToString('N'))

try {
    $gh = (Get-Command gh.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $gh) {
        $candidates = @(
            (Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\GitHub CLI\gh.exe')
        )
        $gh = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $gh) {
        throw 'GitHub CLI is not installed. Install it with: winget install --id GitHub.cli -e'
    }

    Write-Host 'Checking GitHub authentication and latest successful build...'
    & $gh auth status 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Sign in to GitHub using your browser.'
        & $gh auth login --hostname github.com --web
        if ($LASTEXITCODE -ne 0) { throw 'GitHub authentication failed.' }
    }

    $raw = & $gh run list --repo $repo --workflow $workflow --limit 15 --json databaseId,status,conclusion,createdAt
    if ($LASTEXITCODE -ne 0) { throw 'Cannot query GitHub Actions builds.' }
    $runs = @($raw | ConvertFrom-Json)
    $success = $runs |
        Where-Object { $_.conclusion -eq 'success' } |
        Sort-Object createdAt -Descending |
        Select-Object -First 1
    if (-not $success) { throw 'No successful Windows build found. Nothing was installed.' }

    # Save the run ID to a normal string variable before passing it to gh.exe.
    # PowerShell may otherwise split object-property syntax in native commands.
    $runId = [string]$success.databaseId
    if ($runId -notmatch '^[0-9]+$') { throw 'Invalid GitHub Actions run ID.' }

    Write-Host ('Downloading verified GitHub build: ' + $runId)
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $downloadArgs = @(
        'run', 'download', $runId,
        '--repo', $repo,
        '--name', 'focuser-hebrew-windows',
        '--dir', $work
    )
    & $gh @downloadArgs
    if ($LASTEXITCODE -ne 0) { throw ('GitHub download failed with exit code ' + $LASTEXITCODE) }

    $zip = Get-ChildItem -LiteralPath $work -Recurse -Filter 'Focuser-Hebrew-Windows.zip' -File |
        Select-Object -First 1
    if (-not $zip) { throw 'Expected Focuser-Hebrew-Windows.zip was not downloaded.' }
    $stage = Join-Path $work 'unpacked'
    Expand-Archive -LiteralPath $zip.FullName -DestinationPath $stage -Force

    $required = @('Focuser-Hebrew.exe', 'focuser-cli.exe', 'focuser-native.exe')
    foreach ($name in $required) {
        $candidate = Join-Path $stage $name
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw ('Missing required executable: ' + $name)
        }
        $fileHeader = [System.IO.File]::OpenRead($candidate)
        try {
            $firstByte = $fileHeader.ReadByte()
            $secondByte = $fileHeader.ReadByte()
            if ($firstByte -ne 77 -or $secondByte -ne 90) {
                throw ('Invalid Windows executable: ' + $name)
            }
        }
        finally { $fileHeader.Dispose() }
    }

    if (Get-Process -Name 'Focuser-Hebrew' -ErrorAction SilentlyContinue) {
        throw 'Close the Hebrew edition before updating it. No files were changed.'
    }

    $backup = $null
    if (Test-Path -LiteralPath $target) {
        $backup = $target + '-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Move-Item -LiteralPath $target -Destination $backup -ErrorAction Stop
    }

    try {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Copy-Item -Path (Join-Path $stage '*') -Destination $target -Recurse -Force
        foreach ($name in $required) {
            if (-not (Test-Path -LiteralPath (Join-Path $target $name) -PathType Leaf)) {
                throw ('Installation verification failed: ' + $name)
            }
        }
    }
    catch {
        Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
        if ($backup) { Move-Item -LiteralPath $backup -Destination $target }
        throw
    }

    $menu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $lnk = Join-Path $menu ([string]::Concat('Focuser ', [char]0x05D1, [char]0x05E2, [char]0x05D1, [char]0x05E8, [char]0x05D9, [char]0x05EA, '.lnk'))
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($lnk)
    $shortcut.TargetPath = Join-Path $target 'Focuser-Hebrew.exe'
    $shortcut.WorkingDirectory = $target
    $shortcut.Description = 'Hebrew edition of Focuser'
    $shortcut.Save()

    Write-Host 'Focuser Hebrew installed successfully.' -ForegroundColor Green
    Write-Host ('Folder: ' + $target)
    Write-Host ('Start Menu shortcut: ' + $lnk)
    if ($backup) { Write-Host ('Previous Hebrew-edition backup: ' + $backup) }
    Write-Warning 'The official Focuser installation was not changed.'
    Write-Warning 'Close the official Focuser UI before launching the Hebrew edition.'
    Write-Warning 'Build passed CI, but blocking behavior must still be tested on this PC.'
}
catch {
    Write-Host ('Installation stopped: ' + $_.Exception.Message) -ForegroundColor Red
    throw
}
