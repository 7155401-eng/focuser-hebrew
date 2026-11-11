# התקנת גרסת Focuser העברית מתוצאת בנייה מאומתת של GitHub Actions.
# המתקין הרשמי נשאר ללא שינוי. אין שינוי ברשימות חסימה או בקובץ hosts.
$ErrorActionPreference = 'Stop'
$repo = '7155401-eng/focuser-hebrew'
$workflow = 'build-hebrew-windows.yml'
$target = Join-Path $env:LOCALAPPDATA 'Programs\Focuser-Hebrew'
$tmp = Join-Path $env:TEMP 'Focuser-Hebrew-Install'
try {
    $gh = (Get-Command gh.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $gh) {
        $gh = @("$env:ProgramFiles\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe") |
            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $gh) {
        $winget = (Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
        if (-not $winget) { throw 'חסר GitHub CLI ו-winget אינו זמין.' }
        & $winget install --id GitHub.cli --exact --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { throw 'התקנת GitHub CLI נכשלה.' }
        $gh = @("$env:ProgramFiles\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe") |
            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $gh) { throw 'יש לפתוח PowerShell מחדש לאחר התקנת GitHub CLI.' }
    }
    & $gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'נדרשת התחברות ל-GitHub כדי להוריד את תוצאת הבנייה.' -ForegroundColor Yellow
        & $gh auth login --hostname github.com --web
        if ($LASTEXITCODE -ne 0) { throw 'התחברות ל-GitHub נכשלה.' }
    }

    Write-Host 'בודק בנייה מוצלחת של הגרסה העברית...' -ForegroundColor Cyan
    $raw = & $gh run list --repo $repo --workflow $workflow --limit 10 --json databaseId,status,conclusion,createdAt
    if ($LASTEXITCODE -ne 0) { throw 'לא ניתן לקרוא את תוצאות הבנייה ב-GitHub.' }
    $runs = @($raw | ConvertFrom-Json)
    $success = $runs | Where-Object { $_.conclusion -eq 'success' } |
        Sort-Object createdAt -Descending | Select-Object -First 1
    if (-not $success) {
        $latest = $runs | Sort-Object createdAt -Descending | Select-Object -First 1
        $status = if ($latest) { "$($latest.status) / $($latest.conclusion)" } else { 'לא נמצאה הרצה' }
        throw "אין כרגע גרסת Windows שנבנתה בהצלחה. מצב הבנייה: $status. אין לבצע התקנה של קובץ שלא נבנה ואומת."
    }
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    & $gh run download $success.databaseId --repo $repo --name focuser-hebrew-windows --dir $tmp
    if ($LASTEXITCODE -ne 0) { throw 'הורדת תוצאת הבנייה נכשלה.' }
    $zip = Get-ChildItem -LiteralPath $tmp -Filter 'Focuser-Hebrew-Windows.zip' -Recurse -File | Select-Object -First 1
    if (-not $zip) { throw 'לא נמצא קובץ ZIP בתוצאת הבנייה.' }
    $staging = Join-Path $tmp 'unpacked'
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    Expand-Archive -LiteralPath $zip.FullName -DestinationPath $staging
    $exe = Join-Path $staging 'Focuser-Hebrew.exe'
    if (-not (Test-Path -LiteralPath $exe)) { throw 'הארכיון אינו מכיל את תוכנת Focuser העברית.' }
    foreach ($name in @('focuser-cli.exe','focuser-native.exe')) {
        if (-not (Test-Path (Join-Path $staging $name))) { throw "חסר רכיב חובה: $name" }
    }

    # לא מחליפים קובץ בזמן שהוא רץ, ולא עוצרים בכוח תהליך נעול.
    $running = @(Get-Process -Name 'Focuser-Hebrew' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) { throw 'גרסת Focuser העברית פועלת כרגע. סגור אותה לפני עדכון הקבצים.' }
    $backup = $null
    if (Test-Path -LiteralPath $target) {
        $backup = $target + '-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Rename-Item -LiteralPath $target -NewName (Split-Path -Leaf $backup)
    }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    try {
        Copy-Item -Path (Join-Path $staging '*') -Destination $target -Recurse -Force
        if (-not (Test-Path (Join-Path $target 'Focuser-Hebrew.exe'))) { throw 'העתקת התוכנה נכשלה.' }
    } catch {
        Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
        if ($backup) { Rename-Item -LiteralPath $backup -NewName (Split-Path -Leaf $target) }
        throw
    }

    $shortcutDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut((Join-Path $shortcutDir 'Focuser בעברית.lnk'))
    $link.TargetPath = Join-Path $target 'Focuser-Hebrew.exe'
    $link.WorkingDirectory = $target
    $link.Description = 'Focuser בעברית — גרסה מותאמת ונפרדת'
    $link.Save()

    Write-Host 'הגרסה העברית הותקנה בתיקייה נפרדת.' -ForegroundColor Green
    Write-Host "מיקום: $target"
    if ($backup) { Write-Host "גיבוי הגרסה העברית הקודמת: $backup" }
    Write-Host 'התוכנה הרשמית לא הוחלפה. סגור אותה דרך הממשק לפני הפעלת הגרסה העברית.'
    Write-Host 'לא נוסתה בפועל על המחשב הזה; יש לבדוק את מסכי החסימה ולוח הזמנים לפני הסתמכות עליה.'
} catch {
    Write-Host "ההתקנה נעצרה: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
