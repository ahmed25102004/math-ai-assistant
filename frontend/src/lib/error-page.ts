export function renderErrorPage(err?: any): string {
  const errMsg =
    err?.stack ||
    err?.message ||
    (typeof err === "string" ? err : JSON.stringify(err)) ||
    "SSR Processing Error";
  return `<!doctype html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8" />
    <title>خطأ في الخادم — معلم الرياضيات الذكي</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      body { font: 15px/1.5 system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; display: grid; place-items: center; min-height: 100vh; margin: 0; padding: 1.5rem; }
      .card { max-width: 36rem; width: 100%; text-align: center; padding: 2rem; background: #1e293b; border-radius: 1rem; border: 1px solid #334155; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }
      h1 { font-size: 1.25rem; margin: 0 0 0.5rem; color: #38bdf8; }
      p { color: #94a3b8; margin: 0 0 1rem; font-size: 0.9rem; }
      pre { background: #090d16; color: #f43f5e; padding: 1rem; border-radius: 0.5rem; text-align: left; direction: ltr; font-size: 0.75rem; overflow-x: auto; max-height: 15rem; white-space: pre-wrap; }
      .actions { display: flex; gap: 0.75rem; justify-content: center; flex-wrap: wrap; margin-top: 1.5rem; }
      a, button { padding: 0.6rem 1.2rem; border-radius: 0.5rem; font-weight: 600; cursor: pointer; text-decoration: none; border: none; }
      .primary { background: #38bdf8; color: #0f172a; }
      .secondary { background: #334155; color: #fff; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>منصة معلم الرياضيات البحتة الذكي 🎓</h1>
      <p>حدث خطأ أثناء المعالجة الأولية على السيرفر (SSR). التفاصيل التقنية الكاشفة:</p>
      <pre>${errMsg}</pre>
      <div class="actions">
        <a class="primary" href="/login">صفحة تسجيل الدخول 🔐</a>
        <button class="secondary" onclick="location.reload()">إعادة التحميل</button>
      </div>
    </div>
  </body>
</html>`;
}
