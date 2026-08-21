import { useEffect, useState } from "react";
import { createFileRoute, Link, useNavigate, useSearch } from "@tanstack/react-router";
import { motion } from "motion/react";
import { ArrowLeft, LogIn, ShieldCheck, KeyRound, UserCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { DEMO_ACCOUNTS, homeForRole, useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import { env } from "@/config/env";
import { BrandMark } from "@/components/app/BrandMark";

export const Route = createFileRoute("/login")({
  validateSearch: (s: Record<string, unknown>): { redirect?: string } =>
    typeof s.redirect === "string" ? { redirect: s.redirect } : {},
  head: () => ({
    meta: [
      { title: "تسجيل الدخول — منصة معلم الرياضيات" },
      {
        name: "description",
        content: "تسجيل دخول الطلاب والمعلمين لمنصة مادة الرياضيات البحتة الذكية",
      },
    ],
  }),
  component: LoginPage,
});

function LoginPage() {
  const { signIn, user, ready } = useAuth();
  const navigate = useNavigate();
  const { redirect } = useSearch({ from: "/login" });
  
  const [mode, setMode] = useState<"pin" | "password">("pin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [studentName, setStudentName] = useState("");
  const [pinCode, setPinCode] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (ready && user) navigate({ to: redirect ?? homeForRole(user.role) });
  }, [ready, user, redirect, navigate]);

  const onPasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    const res = await signIn(email, password, remember);
    setSubmitting(false);
    if (!res.ok) {
      toast.error(res.error);
      return;
    }
    toast.success(`مرحباً بك، ${res.user.name}`);
    navigate({ to: redirect ?? homeForRole(res.user.role) });
  };

  const onPinSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const apiBase = env.API_BASE_URL;
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
    } catch {
      toast.error("تعذر الاتصال بالسيرفر. يرجى التأكد من تشغيل الخادم");
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
            <span className="text-xl font-bold">منصة المعلم الذكي لمادة الرياضيات 🎓</span>
            <BrandMark className="size-10" />
          </Link>
          <h1 className="mt-8 text-3xl leading-tight font-extrabold tracking-tight">
            مساعدك التفاعلي الذكي في مادة الرياضيات البحتة
          </h1>
          <p className="text-muted-foreground mt-4 max-w-md leading-relaxed text-sm">
            أهلاً بك عزيزي الطالب! قم بتسجيل الدخول بالرمز السري الخص بك للبدء في حل المسائل والتفاعل مع المعلم المساعد المعتمد على منهجك الدراسي.
          </p>

          <div className="mt-8 space-y-3">
            <p className="text-xs font-semibold text-muted-foreground mb-2">حسابات تجريبية للمعلم والمدير:</p>
            {DEMO_ACCOUNTS.map((a) => (
              <button
                key={a.email}
                type="button"
                onClick={() => {
                  setMode("password");
                  setEmail(a.email);
                  setPassword(a.password);
                }}
                className="surface-card hover:border-primary/40 flex w-full items-center gap-3 p-3.5 text-right transition-colors rounded-xl border"
              >
                <ShieldCheck className="text-primary size-5" />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold capitalize">
                    {a.role === "admin" ? "المدير / المعلم" : a.role} · {a.name}
                  </p>
                  <p className="text-muted-foreground text-xs font-mono dir-ltr text-left">
                    {a.email}
                  </p>
                </div>
              </button>
            ))}
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="surface-card mx-auto w-full max-w-md p-8 rounded-2xl border shadow-xl"
        >
          <div className="flex items-center justify-between mb-6">
            <Link
              to="/"
              className="text-muted-foreground hover:text-foreground hover:border-primary/40 border-border inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors"
            >
              <ArrowLeft className="size-3.5" /> الرئيسية
            </Link>
            <span className="text-sm font-bold">تسجيل الدخول 🔐</span>
          </div>

          <div className="flex rounded-lg border p-1 mb-6 bg-muted/30">
            <button
              type="button"
              onClick={() => setMode("pin")}
              className={`flex-1 py-2 text-xs font-bold rounded-md transition-all flex items-center justify-center gap-1.5 ${
                mode === "pin" ? "bg-primary text-primary-foreground shadow" : "text-muted-foreground"
              }`}
            >
              <KeyRound className="size-3.5" /> 🎓 دخول الطالب (PIN)
            </button>
            <button
              type="button"
              onClick={() => setMode("password")}
              className={`flex-1 py-2 text-xs font-bold rounded-md transition-all flex items-center justify-center gap-1.5 ${
                mode === "password" ? "bg-primary text-primary-foreground shadow" : "text-muted-foreground"
              }`}
            >
              <UserCheck className="size-3.5" /> 🔐 المعلم / المدير
            </button>
          </div>

          {mode === "pin" ? (
            <form onSubmit={onPinSubmit} className="space-y-4">
              <div>
                <Label htmlFor="studentName" className="text-xs font-semibold">اسم الطالب بالكامل</Label>
                <Input
                  id="studentName"
                  type="text"
                  placeholder="أدخل اسمك الشخصي"
                  value={studentName}
                  onChange={(e) => setStudentName(e.target.value)}
                  required
                  className="mt-1.5"
                />
              </div>
              <div>
                <Label htmlFor="pinCode" className="text-xs font-semibold">الرمز السري (PIN Code)</Label>
                <Input
                  id="pinCode"
                  type="password"
                  placeholder="أدخل الرمز السري الخاص بك"
                  value={pinCode}
                  onChange={(e) => setPinCode(e.target.value)}
                  required
                  className="mt-1.5 font-mono text-center tracking-widest text-lg"
                />
              </div>

              <Button type="submit" className="w-full font-bold mt-2" size="lg" disabled={submitting}>
                {submitting ? "جاري الدخول..." : "دخول المنصة 🚀"}
              </Button>
            </form>
          ) : (
            <form onSubmit={onPasswordSubmit} className="space-y-4">
              <div>
                <Label htmlFor="email" className="text-xs font-semibold">البريد الإلكتروني</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="name@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="mt-1.5 font-mono text-left dir-ltr"
                />
              </div>
              <div>
                <Label htmlFor="password" className="text-xs font-semibold">كلمة السر</Label>
                <Input
                  id="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="mt-1.5 font-mono"
                />
              </div>

              <div className="flex items-center justify-between text-xs">
                <label className="flex items-center gap-2 cursor-pointer">
                  <Checkbox checked={remember} onCheckedChange={(c) => setRemember(!!c)} />
                  <span>تذكرني على هذا الجهاز</span>
                </label>
              </div>

              <Button type="submit" className="w-full font-bold mt-2" size="lg" disabled={submitting}>
                {submitting ? "جاري تسجيل الدخول..." : "تسجيل الدخول 🔑"}
              </Button>
            </form>
          )}
        </motion.div>
      </div>
    </div>
  );
}
