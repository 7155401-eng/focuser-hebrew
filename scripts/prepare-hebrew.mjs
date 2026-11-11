/**
 * שילוב עברית במקור Focuser 0.11.5 לצורך בנייה מותאמת.
 * אין שינוי במנגנון החסימה. יש להריץ מתוך תהליך בנייה מבוקר.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const thisDir = path.dirname(fileURLToPath(import.meta.url));
const sourceDir = path.resolve(process.argv[2] ?? path.join(thisDir, "..", "upstream"));
const translationsDir = path.resolve(process.argv[3] ?? path.join(thisDir, ".."));
const relative = (...parts) => path.join(sourceDir, ...parts);
const read = file => fs.readFileSync(file, "utf8");
const write = (file, value) => fs.writeFileSync(file, value, "utf8");
const requireTrue = (condition, message) => { if (!condition) throw new Error(message); };
const replaceExact = (value, before, after, label) => {
  requireTrue(value.includes(before), "מבנה המקור השתנה: " + label);
  return value.replace(before, after);
};
const pkg = JSON.parse(read(relative("crates", "focuser-ui", "frontend", "package.json")));
requireTrue(pkg.version === "0.11.5", "נדרשת גרסת מקור v0.11.5 בדיוק");

const front = relative("crates", "focuser-ui", "frontend");
const english = JSON.parse(read(path.join(front, "messages", "en.json")));
const hebrew = JSON.parse(read(path.join(translationsDir, "he.json")));
const sourceKeys = Object.keys(english).sort();
requireTrue(JSON.stringify(sourceKeys) === JSON.stringify(Object.keys(hebrew).sort()), "מפתחות התרגום אינם תואמים");
const refs = value => [...(typeof value === "string" ? value : JSON.stringify(value)).matchAll(/\{[A-Za-z][A-Za-z0-9_]*\}/g)].map(x => x[0]).sort();
for (const key of sourceKeys) {
  requireTrue(JSON.stringify(refs(english[key])) === JSON.stringify(refs(hebrew[key])), "משתנים לא תואמים: " + key);
}
write(path.join(front, "messages", "he.json"), JSON.stringify(hebrew, null, 2) + "\n");

const inlangFile = path.join(front, "project.inlang", "settings.json");
const inlang = JSON.parse(read(inlangFile));
requireTrue(Array.isArray(inlang.locales), "לא נמצא מערך שפות");
if (!inlang.locales.includes("he")) inlang.locales.push("he");
write(inlangFile, JSON.stringify(inlang, null, 2) + "\n");

const langFile = path.join(front, "src", "lib", "language.ts");
let language = read(langFile);
if (!language.includes('  he: "עברית",')) {
  language = replaceExact(language, '  ko: "한국어",', '  ko: "한국어",\n  he: "עברית",', "בחירת שפה");
}
if (!language.includes("FOCUSER_HEBREW_LOCALE")) {
  language = replaceExact(language, "function apply(locale: Locale) {",
    'function apply(locale: Locale) {\n  // FOCUSER_HEBREW_LOCALE\n  document.documentElement.lang = locale;\n  document.documentElement.dir = locale === "he" ? "rtl" : "ltr";', "החלת שפה");
  language = replaceExact(language, "export function isLocale(value:",
    '// ברירת מחדל בעברית; העדפה שמורה תיטען דרך ההגדרות.\nif (getLocale() === "en") setLocale("he", { reload: false });\n\nexport function isLocale(value:', "ברירת מחדל");
}
write(langFile, language);

const htmlFile = path.join(front, "index.html");
write(htmlFile, replaceExact(read(htmlFile), '<html lang="en" class="dark">', '<html lang="he" dir="rtl" class="dark">', "כיווניות מסמך"));

const cssFile = path.join(front, "src", "index.css");
let css = read(cssFile);
if (!css.includes("FOCUSER_HEBREW_RTL")) {
  css += '\n/* FOCUSER_HEBREW_RTL: scoped exclusively to Hebrew */\n' +
    'html[lang="he"] { direction: rtl; }\n' +
    'html[lang="he"] body { direction: rtl; font-family: "Segoe UI", Arial, sans-serif; }\n' +
    'html[lang="he"] input[type="url"], html[lang="he"] input[type="email"],\n' +
    'html[lang="he"] input[type="number"], html[lang="he"] input[dir="ltr"],\n' +
    'html[lang="he"] code { direction: ltr; text-align: left; }\n';
}
write(cssFile, css);

// Strings outside the WebView, including system tray and warning dialogs.
const rustFile = relative("crates", "focuser-ui", "src", "i18n.rs");
let rust = read(rustFile);
const heRust = {
  tray_open: "פתיחת Focuser",
  tray_quit: "יציאה",
  locked_title: "Focuser נעול",
  locked_body: "ביקשת להשאיר את Focuser פעיל עד לסיום הנעילה. אי אפשר לצאת עדיין: {reason}.",
  locked_ok: "אישור",
  extension_title: "נדרש תוסף לדפדפן",
  extension_body: "Focuser סגר את {browser} כי התוסף אינו מותקן. התקן אותו מחנות {store} כדי להשתמש ב־{browser} בזמן חסימה.",
  extension_install: "התקנת התוסף עבור {browser}",
  extension_dismiss: "סגירה",
  extension_incognito_title: "יש לאפשר את התוסף בגלישה בסתר",
  extension_incognito_body: "Focuser סגר את {browser} כי התוסף אינו מורשה לפעול בגלישה בסתר. אפשר זאת בהגדרות כדי להמשיך להשתמש ב־{browser}.",
  extension_incognito_action: "פתיחת הגדרות התוסף עבור {browser}",
  extension_warning_body: "Focuser יסגור את {browser} בעוד {seconds} שניות כי התוסף אינו מותקן. התקן אותו מחנות {store} כדי להמשיך להשתמש ב־{browser}.",
  extension_incognito_warning_body: "Focuser יסגור את {browser} בעוד {seconds} שניות כי התוסף אינו מורשה בגלישה בסתר. אפשר זאת בהגדרות כדי להמשיך להשתמש ב־{browser}.",
  closing_title: "יש לשמור את העבודה",
  closing_body: "Focuser יסגור את {apps} בעוד {minutes} דקות. שמור את העבודה כעת."
};
if (!rust.includes("const HE: Strings")) {
  const table = "const HE: Strings = Strings {\n" +
    Object.entries(heRust).map(([name, value]) => "    " + name + ": " + JSON.stringify(value) + ",").join("\n") +
    "\n};\n\n";
  rust = replaceExact(rust, "const EN: Strings = Strings {", table + "const EN: Strings = Strings {", "הודעות Rust");
}
if (!rust.includes('"he" => &HE')) {
  rust = replaceExact(rust, '        "ko" => &KO,', '        "ko" => &KO,\n        "he" => &HE,', "בחירת שפת Rust");
}
rust = rust.replaceAll('["es", "fr", "de", "pt", "it", "ru", "zh", "ja", "ko"]',
  '["he", "es", "fr", "de", "pt", "it", "ru", "zh", "ja", "ko"]');
rust = rust.replaceAll('["en", "es", "fr", "de", "pt", "it", "ru", "zh", "ja", "ko"]',
  '["en", "he", "es", "fr", "de", "pt", "it", "ru", "zh", "ja", "ko"]');
write(rustFile, rust);

console.log("עברית שולבה במקור: " + (sourceKeys.length - 1) + " מחרוזות ממשק, הודעות Rust ו-RTL.");
