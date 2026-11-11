# תרגום עברי — Focuser v0.11.5

הקבצים מיועדים להוספת שפה למיזם המקורי. הם **אינם תוסף טעינה אוטומטי** להתקנה הקיימת.

## קבצים

- `he.json` — קובץ התרגום של ממשק המחשב, תואם למבנה `crates/focuser-ui/frontend/messages/en.json`.
- `he.yml` — קובץ התרגום של תוסף הדפדפן, תואם למבנה `extension/locales/en.yml`.

## שילוב רשמי במיזם

1. להוסיף את `he.json` אל `crates/focuser-ui/frontend/messages/`.
2. להוסיף את הקוד `he` למערך `locales` שבקובץ `crates/focuser-ui/frontend/project.inlang/settings.json`, ולהוסיף `he: "עברית"` למילון `LANGUAGE_NAMES` ב־`crates/focuser-ui/frontend/src/lib/language.ts`.
3. להוסיף את הודעות המערכת בשפת עברית ל־`crates/focuser-ui/src/i18n.rs` ולמפות את `he` במנגנון בחירת השפה; הודעות אלו אינן נטענות מקובצי JSON בגרסה 0.11.5.
4. להוסיף את `he.yml` אל `extension/locales/` ולהתאים את הגדרות שפות התוסף, ככל שנדרש על ידי מערכת WXT.
5. להוסיף הגדרות RTL לכיוון הטקסט/הרכיבים בממשק, עם שמירת LTR לשדות כתובת, דומיין, נתיבים וקיצורי דרך.
6. להריץ בדיקות יחידה ו־build של יישום המחשב ותוסף הדפדפן, לבדוק פריסה וכיווניות, ולהגיש Pull Request למאגר המקורי.

**חשוב:** התוכנה המקורית מקמפלת את השפות בעת הבנייה. העתקת `he.json` ו־`he.yml` לתיקיית ההתקנה הקיימת לא תוסיף שפת ממשק. כדי לשמור על עדכונים רגילים, יש להמתין לשילוב רשמי בפרויקט ולהתקין את המהדורה הרשמית שתכלול עברית.

## בדיקות שבוצעו

- כל 386 שמות המפתחות של קובץ הממשק, כולל `$schema`, הושוו למקור מגרסה `v0.11.5` ונמצאו תואמים.
- כל 48 המחרוזות שמכילות משתנים דינמיים נבדקו מבחינת שמות המשתנים.
- כל 103 מפתחות התוסף הושוו לקובץ המקור ונמצאו תואמים.
- **לא** הורצה בדיקת בנייה של האפליקציה, **לא** הותקנה גרסה עברית, ולא נעשה שינוי בהתקנה המקורית.

מקור: https://github.com/aadeshrao123/Focuser
## הורדה ב־Windows באמצעות PowerShell

אין צורך בהורדה מהדפדפן. פתח PowerShell והדבק את הקוד הבא:

```powershell
$ErrorActionPreference = 'Stop'
$base = 'https://raw.githubusercontent.com/7155401-eng/focuser-hebrew/main'
$folder = Join-Path $env:LOCALAPPDATA 'Focuser-Hebrew'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
foreach ($name in @('he.json','he.yml')) {
    Invoke-WebRequest -Uri "$base/$name" -OutFile (Join-Path $folder $name) -UseBasicParsing
}
(Get-Content (Join-Path $folder 'he.json') -Raw -Encoding UTF8 | ConvertFrom-Json).nav_dashboard
Write-Host "קובצי התרגום נמצאים ב: $folder"
```

הפקודה מורידה **רק את שני קובצי התרגום** למיקום `%LOCALAPPDATA%\\Focuser-Hebrew`. היא אינה מחליפה את קובצי התוכנה, אינה משנה כללי חסימה ואינה פוגעת במנגנון העדכון. קיימת גם גרסה של הסקריפט עם בדיקת תקינות בשם [download-translations.ps1](download-translations.ps1).

**הערה חשובה:** גרסה 0.11.5 של Focuser אינה מאפשרת לבחור שפה מקובץ JSON חיצוני. לפיכך, הורדת הקבצים לבדה **לא תעביר את ממשק התוכנה לעברית**. כדי לשמור על התקנה רשמית ועדכונים רגילים, יש לשלב את קובצי השפה ואת ההתאמות הנדרשות במקור הרשמי, לאחר בדיקות ובניית מהדורה רשמית. שום סקריפט במאגר הזה אינו מתיימר לעקוף מגבלה זו.

## סטטוס הפרסום

- התרגום הראשי: `he.json` — 385 מחרוזות ועוד ערך `$schema`.
- תוסף הדפדפן: `he.yml` — 103 מחרוזות.
- הועלו כקובצי שפה נפרדים, בלי שינוי בקוד Focuser.
- התאמת ממשק מלאה ל־RTL, שילוב הודעות Rust ובדיקת בנייה עדיין לא בוצעו.

## גרסת Windows מותאמת לעברית

בנוסף לקובצי השפה, קיימים כעת במאגר כלים לבניית גרסת Focuser 0.11.5 עם עברית, RTL והודעות מערכת מתורגמות. מנגנון החסימה נשאר ללא שינוי.

### התקנה מתוך GitHub Actions (מומלץ)

הקובץ [install-hebrew.ps1](install-hebrew.ps1) מאתר את הבנייה המוצלחת האחרונה, מוריד את תוצאת הבנייה ומתקין אותה בתיקייה נפרדת. אם אין בנייה מוצלחת, הוא נעצר ללא התקנה.

פקודת PowerShell:

```powershell
$p = Join-Path $env:TEMP 'focuser-hebrew-install.ps1'
Invoke-WebRequest 'https://raw.githubusercontent.com/7155401-eng/focuser-hebrew/main/install-hebrew.ps1' -OutFile $p -UseBasicParsing
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p
```

### בנייה מקומית חלופית

הקובץ [build-local.ps1](build-local.ps1) מוריד את קוד המקור הרשמי, בודק את התרגום, מתקין כלי בנייה לפי הצורך, ומבצע בנייה במחשב Windows.

```powershell
$p = Join-Path $env:TEMP 'focuser-hebrew-build.ps1'
Invoke-WebRequest 'https://raw.githubusercontent.com/7155401-eng/focuser-hebrew/main/build-local.ps1' -OutFile $p -UseBasicParsing
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p
```

הגרסה העברית מותקנת ב־`%LOCALAPPDATA%\Programs\Focuser-Hebrew`. הגרסה הרשמית אינה נדרסת. יש לסגור אותה דרך הממשק לפני פתיחת העברית, בלי לעצור בכוח חסימה נעולה.

**אזהרה:** הקובץ המותאם אינו חתום בחתימת היצרן; אין להניח שהחסימה נבדקה על המחשב עד לבדיקה מעשית. עדכונים רשמיים לגרסה המותאמת דורשים בנייה חוזרת או שילוב השפה בפרויקט המקורי. חסימת דומיינים ב־hosts וחסימת תוכנות פועלות ללא תוסף; חסימת URL/מילות מפתח עדיין דורשת תוסף.
