# Focuser בעברית: בנייה מקומית, ללא החלפת ההתקנה הרשמית.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Find-Tool([string]$name,[string[]]$paths) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) { return $cmd.Source }
  foreach ($path in $paths) { if ($path -and (Test-Path $path)) { return $path } }
  return $null
}
function Run([string]$exe,[string[]]$args,[string]$folder) {
  Push-Location $folder
  try {
    & $exe @args
    if ($LASTEXITCODE -ne 0) { throw "הפקודה $exe נכשלה (קוד $LASTEXITCODE)." }
  } finally { Pop-Location }
}
function Need([string]$name,[string[]]$paths,[string]$package) {
  $tool = Find-Tool $name $paths
  if ($tool) { return $tool }
  $winget = Find-Tool 'winget.exe' @()
  if (-not $winget) { throw "חסר $name ו-winget אינו מותקן." }
  Write-Host "מתקין: $package" -ForegroundColor Yellow
  Run $winget @('install','--id',$package,'--exact','--accept-source-agreements','--accept-package-agreements') $env:TEMP
  $tool = Find-Tool $name $paths
  if (-not $tool) { throw 'נדרשת פתיחה מחדש של PowerShell והרצת אותה פקודה.' }
  return $tool
}
try {
  if (-not [Environment]::Is64BitOperatingSystem) { throw 'נדרש Windows x64.' }
  $root = Join-Path $env:LOCALAPPDATA 'Focuser-Hebrew-Build'
  $dir = Join-Path $root 'source'
  $tools = Join-Path $root 'translation'
  $archive = Join-Path $root 'v0.11.5.zip'
  $src = Join-Path $dir 'Focuser-0.11.5'
  $target = Join-Path $env:LOCALAPPDATA 'Programs\Focuser-Hebrew'
  New-Item -ItemType Directory -Force -Path $root,$dir,$tools | Out-Null
  if (-not (Test-Path $archive)) {
    Invoke-WebRequest 'https://github.com/aadeshrao123/Focuser/archive/refs/tags/v0.11.5.zip' -OutFile $archive -UseBasicParsing
  }
  if (-not (Test-Path (Join-Path $src 'Cargo.toml'))) {
    Expand-Archive -LiteralPath $archive -DestinationPath $dir -Force
  }
  if (-not (Test-Path (Join-Path $src 'Cargo.toml'))) { throw 'קוד המקור לא חולץ כראוי.' }
  $base = 'https://raw.githubusercontent.com/7155401-eng/focuser-hebrew/main'
  Invoke-WebRequest "$base/he.json" -OutFile (Join-Path $tools 'he.json') -UseBasicParsing
  Invoke-WebRequest "$base/scripts/prepare-hebrew.mjs" -OutFile (Join-Path $tools 'prepare-hebrew.mjs') -UseBasicParsing
  $node = Need 'node.exe' @('C:\Program Files\nodejs\node.exe') 'OpenJS.NodeJS.LTS'
  $npm = Need 'npm.cmd' @('C:\Program Files\nodejs\npm.cmd') 'OpenJS.NodeJS.LTS'
  $npx = Need 'npx.cmd' @('C:\Program Files\nodejs\npx.cmd') 'OpenJS.NodeJS.LTS'
  $rustup = Need 'rustup.exe' @((Join-Path $env:USERPROFILE '.cargo\bin\rustup.exe')) 'Rustlang.Rustup'
  $cargo = Need 'cargo.exe' @((Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe')) 'Rustlang.Rustup'
  Run $rustup @('default','stable-x86_64-pc-windows-msvc') $root
  $vswhere = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Microsoft Visual Studio\Installer\vswhere.exe'
  $compiler = $null
  if (Test-Path $vswhere) { $compiler = & $vswhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath }
  if (-not $compiler) {
    $winget = Find-Tool 'winget.exe' @()
    if (-not $winget) { throw 'נדרש Visual Studio Build Tools (C++).' }
    Write-Host 'מתקין כלי C++ הדרושים לבנייה. ההתקנה עשויה לדרוש הרשאת מנהל.' -ForegroundColor Yellow
    Run $winget @('install','--id','Microsoft.VisualStudio.2022.BuildTools','--exact',
      '--accept-source-agreements','--accept-package-agreements',
      '--override','--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended') $root
    throw 'יש לפתוח מחדש את PowerShell ולהריץ שוב את אותה פקודה.'
  }
  Write-Host 'מתאים את שפת הממשק לעברית...' -ForegroundColor Cyan
  Run $node @((Join-Path $tools 'prepare-hebrew.mjs'),$src,$tools) $root
  $front = Join-Path $src 'crates\focuser-ui\frontend'
  Run $npm @('ci') $front
  Run $npm @('run','typecheck') $front
  $arch = 'x86_64-pc-windows-msvc'
  Run $cargo @('build','--release','--target',$arch,'-p','focuser-cli','-p','focuser-native') $src
  $release = Join-Path $src "target\$arch\release"
  $sidecars = Join-Path $src 'crates\focuser-ui\binaries'
  New-Item -ItemType Directory -Force -Path $sidecars | Out-Null
  foreach ($name in @('focuser-cli','focuser-native')) {
    Copy-Item (Join-Path $release "$name.exe") (Join-Path $sidecars "$name-$arch.exe") -Force
  }
  Run $cargo @('test','-p','focuser-ui','i18n') $src
  Run $npx @('--yes','@tauri-apps/cli@2','build','--target',$arch,'--no-bundle') (Join-Path $src 'crates\focuser-ui')
  $built = Join-Path $release 'focuser-ui.exe'
  if (-not (Test-Path $built)) { throw 'הקובץ לא נבנה.' }
  if (Get-Process -Name 'Focuser-Hebrew' -ErrorAction SilentlyContinue) {
    throw 'גרסת Focuser בעברית פועלת כעת. סגור אותה לפני עדכון.'
  }
  $backup = $null
  if (Test-Path $target) {
    $backup = $target + '-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Rename-Item -LiteralPath $target -NewName (Split-Path -Leaf $backup)
  }
  try {
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Copy-Item $built (Join-Path $target 'Focuser-Hebrew.exe')
    foreach ($name in @('focuser-cli','focuser-native')) {
      Copy-Item (Join-Path $release "$name.exe") (Join-Path $target "$name.exe")
      Copy-Item (Join-Path $sidecars "$name-$arch.exe") (Join-Path $target "$name-$arch.exe")
    }
    Copy-Item (Join-Path $tools 'he.json') (Join-Path $target 'he.json')
  } catch {
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
    if ($backup) { Rename-Item -LiteralPath $backup -NewName (Split-Path -Leaf $target) }
    throw
  }
  $shell = New-Object -ComObject WScript.Shell
  $menu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Focuser בעברית.lnk'
  $link = $shell.CreateShortcut($menu)
  $link.TargetPath = Join-Path $target 'Focuser-Hebrew.exe'
  $link.WorkingDirectory = $target
  $link.Save()
  Write-Host 'הבנייה הסתיימה. קיצור דרך בשם Focuser בעברית נוסף לתפריט התחל.' -ForegroundColor Green
  Write-Host "התקנה: $target"
  if ($backup) { Write-Host "גיבוי קודם: $backup" }
  Write-Warning 'Focuser הרשמי לא שונה. סגור אותו לפני הפעלת הגרסה העברית. הבנייה והחסימות טרם נבדקו במחשב שלך.'
} catch {
  Write-Host "תהליך הבנייה נעצר: $($_.Exception.Message)" -ForegroundColor Red
  throw
}
