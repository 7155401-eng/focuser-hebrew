$ErrorActionPreference = 'Stop'

# הורדת קובצי שפה בלבד: ללא שינוי בקובצי תוכנת Focuser או בהגדרות החסימה.
$base = 'https://raw.githubusercontent.com/7155401-eng/focuser-hebrew/main'
$target = Join-Path $env:LOCALAPPDATA 'Focuser-Hebrew'

New-Item -ItemType Directory -Path $target -Force | Out-Null

foreach ($name in @('he.json', 'he.yml')) {
    $uri = "$base/$name"
    $destination = Join-Path $target $name
    Invoke-WebRequest -Uri $uri -OutFile $destination -UseBasicParsing
    if ((Get-Item $destination).Length -lt 100) {
        throw "הקובץ $name ריק או קטן מדי"
    }
    Write-Host "התקבל: $destination"
}

$json = Get-Content -LiteralPath (Join-Path $target 'he.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($json.nav_dashboard -ne 'לוח בקרה') {
    throw 'אימות קובץ השפה העברי נכשל'
}

Write-Host ''
Write-Host 'קובצי התרגום העבריים הורדו ונבדקו.' -ForegroundColor Green
Write-Host "תיקיית התרגום: $target"
Write-Warning 'Focuser 0.11.5 אינו יודע לטעון קובץ שפה חיצוני. קבצים אלו אינם משנים את שפת התוכנה המותקנת. להפעלת עברית דרוש שילוב במיזם הרשמי ועדכון תוכנה רשמי.'
