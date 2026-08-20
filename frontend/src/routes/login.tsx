import { useEffect, useState } from "react";
import { createFileRoute, Link, useNavigate, useSearch } from "@tanstack/react-router";
import { motion } from "motion/react";
import { ArrowLeft, LogIn, ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { DEMO_ACCOUNTS, homeForRole, useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import { BrandMark } from "@/components/app/BrandMark";

export const Route = createFileRoute("/login")({
  validateSearch: (s: Record<string, unknown>): { redirect?: string } =>
    typeof s.redirect === "string" ? { redirect: s.redirect } : {},
  head: () => ({
    meta: [
      { title: "Sign in — Sensei" },
      {
        name: "description",
        content: "Sign in to Sensei to access your grounded study workspace.",
      },
      { property: "og:title", content: "Sign in — Sensei" },
      { property: "og:description", content: "Access your grounded study workspace." },
    ],
  }),
  component: LoginPage,
});

function LoginPage() {
  const { signIn, user, ready } = useAuth();
  const navigate = useNavigate();
  const { redirect } = useSearch({ from: "/login" });
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (ready && user) navigate({ to: redirect ?? homeForRole(user.role) });
  }, [ready, user, redirect, navigate]);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    const res = await signIn(email, password, remember);
    setSubmitting(false);
    if (!res.ok) {
      toast.error(res.error);
      return;
    }
    toast.success(`Welcome, ${res.user.name}`);
    navigate({ to: redirect ?? homeForRole(res.user.role) });
  };

  return (
    <div className="bg-background mesh-bg min-h-screen">
      <div className="mx-auto flex min-h-screen max-w-6xl items-center gap-10 px-4 py-10 sm:px-6 lg:grid lg:grid-cols-2">
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="hidden lg:block"
        >
          <Link to="/" className="flex items-center gap-2.5">
            <BrandMark className="size-10" />
            <span className="text-lg font-semibold">Sensei</span>
          </Link>
          <h1 className="mt-8 text-4xl leading-tight font-semibold tracking-tight">
            Grounded learning, one login away.
          </h1>
          <p className="text-muted-foreground mt-4 max-w-md">
            Pick a role to explore the workspace. Each role sees a different surface, matched to
            what they need to do.
          </p>
          <div className="mt-8 space-y-3">
            {DEMO_ACCOUNTS.map((a) => (
              <button
                key={a.email}
                type="button"
                onClick={() => {
                  setEmail(a.email);
                  setPassword(a.password);
                }}
                className="surface-card hover:border-primary/40 flex w-full items-center gap-3 p-4 text-left transition-colors"
              >
                <span className="bg-primary/12 text-primary flex size-10 items-center justify-center rounded-xl text-xs font-bold uppercase">
                  {a.role.slice(0, 2)}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold capitalize">
                    {a.role} · {a.name}
                  </p>
                  <p className="text-muted-foreground text-xs">
                    {a.email} · password: {a.password}
                  </p>
                </div>
                <ShieldCheck className="text-muted-foreground size-4" />
              </button>
            ))}
          </div>
        </motion.div>

        <motion.form
          onSubmit={onSubmit}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="surface-card mx-auto w-full max-w-md p-8"
        >
          <Link
            to="/"
            className="text-muted-foreground hover:text-foreground hover:border-primary/40 border-border inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors"
          >
            <ArrowLeft className="size-3.5" /> Back to home
          </Link>

  const [mode, setMode] = useState<"pin" | "password">("pin");
  const [studentName, setStudentName] = useState("");
  const [pinCode, setPinCode] = useState("");

  const onPinSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const apiBase = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";
      const resp = await fetch(`${apiBase}/auth/student-login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ student_name: studentName, pin_code: pinCode }),
      });
      const data = await resp.json();
      if (!resp.ok) {
        toast.error(data.message || "فشل تسجيل الدخول. تحقق من اسم الطالب والرمز السري وتاريخ التفعيل");
        setSubmitting(false);
        return;
      }
      if (data.session && data.session.access_token) {
        localStorage.setItem("sensei_access_token", data.session.access_token);
        localStorage.setItem("sensei_user", JSON.stringify(data.session.user));
        toast.success(`أهلاً بك يا ${data.session.user.name} في منصة مادة الرياضيات البحتة!`);
        window.location.href = "/workspace";
        return;
      }
    } catch (err: any) {
      toast.error("تعذر الاتصال بالسيرفر. يرجى التأكد من تشغيل المشروع");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="bg-background mesh-bg min-h-screen" dir="rtl">
      <div className="mx-auto flex min-h-screen max-w-6xl items-center gap-10 px-4 py-10 sm:px-6 lg:grid lg:grid-cols-2">
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="hidden lg:block text-right"
        >
          <Link to="/" className="flex items-center gap-2.5 justify-end">
            <span className="text-lg font-semibold">منصة المعلم الذكي لمادة الرياضيات</span>
            <BrandMark className="size-10" />
          </Link>
          <h1 className="mt-8 text-4xl leading-tight font-semibold tracking-tight">
            المعلم المساعد الذكي لمادة الرياضيات البحتة 📐
          </h1>
          <p className="text-muted-foreground mt-4 max-w-md">
            منصة تعتمد على الذكاء الاصطناعي التفاعلي للإجابة عن استفسارات الطلاب وشرح المنهج من كتب وملفات الـ PDF المرفقة بشكل حصري ودعم المعادلات الرياضية.
          </p>
          <div className="mt-8 space-y-3">
            {DEMO_ACCOUNTS.map((a) => (
              <button
                key={a.email}
                type="button"
                onClick={() => {
                  setMode("password");
                  setEmail(a.email);
                  setPassword(a.password);
                }}
                className="surface-card hover:border-primary/40 flex w-full items-center gap-3 p-4 text-right transition-colors"
              >
                <span className="bg-primary/12 text-primary flex size-10 items-center justify-center rounded-xl text-xs font-bold uppercase">
                  {a.role.slice(0, 2)}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold capitalize">
                    حساب تجريبي: {a.role} · {a.name}
                  </p>
                  <p className="text-muted-foreground text-xs">
                    {a.email}
                  </p>
                </div>
                <ShieldCheck className="text-muted-foreground size-4" />
              </button>
            ))}
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="surface-card mx-auto w-full max-w-md p-8 text-right"
        >
          <div className="mb-6 flex gap-2 border-b pb-3">
            <button
              type="button"
              onClick={() => setMode("pin")}
              className={`flex-1 py-2 rounded-lg text-sm font-semibold transition-colors ${
                mode === "pin" ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
              }`}
            >
              🎓 دخول الطالب بالرمز (PIN)
            </button>
            <button
              type="button"
              onClick={() => setMode("password")}
              className={`flex-1 py-2 rounded-lg text-sm font-semibold transition-colors ${
                mode === "password" ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
              }`}
            >
              🔐 دخول المعلم / المدير
            </button>
          </div>

          {mode === "pin" ? (
            <form onSubmit={onPinSubmit}>
              <h2 className="text-2xl font-semibold tracking-tight">تسجيل دخول الطالب</h2>
              <p className="text-muted-foreground mt-1 text-sm">
                أدخل اسمك الشخصي والرمز السري (PIN Code) الخاص بك
              </p>

              <div className="mt-6 space-y-4">
                <div>
                  <Label htmlFor="studentName">اسم الطالب بالكامل</Label>
                  <Input
                    id="studentName"
                    type="text"
                    value={studentName}
                    onChange={(e) => setStudentName(e.target.value)}
                    placeholder="مثال: أحمد محمد"
                    className="mt-1.5 text-right"
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="pinCode">الرمز السري (PIN Code)</Label>
                  <Input
                    id="pinCode"
                    type="password"
                    maxLength={10}
                    value={pinCode}
                    onChange={(e) => setPinCode(e.target.value)}
                    placeholder="أدخل الرمز السري..."
                    className="mt-1.5 text-right tracking-widest"
                    required
                  />
                </div>
              </div>

              <Button type="submit" className="mt-6 w-full font-bold" disabled={submitting}>
                <LogIn className="size-4 ml-2" /> دخول المنصة
              </Button>
            </form>
          ) : (
            <form onSubmit={onSubmit}>
              <h2 className="text-2xl font-semibold tracking-tight">تسجيل دخول الإدارة والمعلمين</h2>
              <p className="text-muted-foreground mt-1 text-sm">
                تسجيل الدخول بالبريد الإلكتروني للوصول إلى لوحة التحكم والوكلاء الذكية
              </p>

              <div className="mt-6 space-y-4">
                <div>
                  <Label htmlFor="email">البريد الإلكتروني</Label>
                  <Input
                    id="email"
                    type="email"
                    autoComplete="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="admin@sensei.ai"
                    className="mt-1.5"
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="password">كلمة المرور</Label>
                  <Input
                    id="password"
                    type="password"
                    autoComplete="current-password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    className="mt-1.5"
                    required
                  />
                </div>
              </div>

              <Button type="submit" className="mt-6 w-full" disabled={submitting}>
                <LogIn className="size-4 ml-2" /> تسجيل الدخول
              </Button>
            </form>
          )}
        </motion.div>
      </div>
    </div>
  );
}

