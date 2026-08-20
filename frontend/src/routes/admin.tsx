import { useEffect, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "motion/react";
import {
  ArrowUpRight,
  FileStack,
  Gauge,
  LayersIcon,
  ListChecks,
  ShieldCheck,
  Sparkles,
  Upload,
} from "lucide-react";
import { AppShell } from "@/components/app/AppShell";
import { BackendStatus } from "@/components/app/BackendStatus";
import { RoleGate } from "@/components/app/RoleGate";
import { StatCard } from "@/components/app/StatCard";
import { Pipeline } from "@/components/app/Pipeline";
import { Button } from "@/components/ui/button";
import { ReviewBadge } from "@/components/app/badges";
import { AsyncSection } from "@/components/app/AsyncState";
import { useServiceQuery } from "@/hooks/useServiceQuery";
import { AdminService, AnalyticsService } from "@/services";
import { useWorkspace } from "@/contexts/WorkspaceContext";

export const Route = createFileRoute("/admin")({
  head: () => ({
    meta: [
      { title: "Admin Dashboard — Sensei" },
      {
        name: "description",
        content:
          "System health, grounding, latency, review queue and pipeline analytics for Sensei admins.",
      },
      { property: "og:title", content: "Admin Dashboard — Sensei" },
      { property: "og:description", content: "Full pipeline observability and grounding health." },
    ],
  }),
  component: () => (
    <RoleGate allow={["admin"]}>
      <AdminDashboard />
    </RoleGate>
  ),
});

function AdminDashboard() {
  const { active } = useWorkspace();
  const workspaceId = active ? active.id : "";
  const analytics = useServiceQuery(["analytics", workspaceId], () =>
    AnalyticsService.get({ workspaceId, range: "30d" }),
  );
  const overview = useServiceQuery(["admin", "overview"], () => AdminService.overview());
  const adminStats = useServiceQuery(["admin", "stats"], () => AdminService.stats());
  const recent = useServiceQuery(["admin", "recent-generations"], () =>
    AdminService.recentGenerations(),
  );
  const documents = adminStats.data?.recentDocuments ?? [];
  const history = recent.data ?? [];
  const stats = overview.data;
  const topicCoverage = analytics.data?.topicCoverage ?? [];
  const overallCoverage =
    topicCoverage.length > 0
      ? Math.round(topicCoverage.reduce((n, t) => n + t.pct, 0) / topicCoverage.length)
      : null;

  return (
    <AppShell
      title="Admin dashboard"
      description="Pipeline health, grounding, latency and review throughput across every workspace."
      actions={
        <>
          <Button asChild variant="outline">
            <Link to="/library">
              <Upload className="size-4" /> Upload material
            </Link>
          </Button>
          <Button asChild>
            <Link to="/studio">
              <Sparkles className="size-4" /> New generation
            </Link>
          </Button>
        </>
      }
    >
      <div className="mb-6">
        <BackendStatus />
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Documents"
          value={stats ? String(stats.documents) : "—"}
          delta={overview.isPending ? "Loading…" : "Indexed across every workspace"}
          icon={FileStack}
          index={0}
        />
        <StatCard
          label="Questions generated"
          value={stats ? String(stats.questions) : "—"}
          delta={overview.isPending ? "Loading…" : "Across all reviewable generations"}
          icon={ListChecks}
          index={1}
        />
        <StatCard
          label="Grounding success"
          value={stats && stats.grounding != null ? `${stats.grounding.toFixed(1)}%` : "—"}
          delta={overview.isPending ? "Loading…" : "Mean citation coverage"}
          icon={ShieldCheck}
          index={2}
        />
        <StatCard
          label="Avg. quality"
          value={stats && stats.quality != null ? `${stats.quality.toFixed(1)} / 10` : "—"}
          delta={overview.isPending ? "Loading…" : "Mean review score"}
          icon={Gauge}
          index={3}
        />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <Pipeline />
        </div>

        <div className="surface-card p-6">
          <h2 className="text-lg font-semibold">Topic coverage</h2>
          <p className="text-muted-foreground text-sm">Across uploaded documents</p>
          <AsyncSection
            isLoading={analytics.isPending}
            error={analytics.error}
            data={analytics.data?.topicCoverage}
            isEmpty={(list) => list.length === 0}
            loadingLabel="Loading coverage…"
            errorTitle="Unable to load coverage"
            emptyTitle="No coverage data yet"
            onRetry={() => void analytics.refetch()}
          >
            {(topicCoverage) => (
              <div className="mt-5 space-y-4">
                {topicCoverage.map((t, i) => (
                  <div key={t.topic}>
                    <div className="flex items-center justify-between text-sm">
                      <span className="font-medium">{t.topic}</span>
                      <span className={t.covered ? "text-success" : "text-warning"}>
                        {t.covered ? "✓ covered" : "⚠ missing"}
                      </span>
                    </div>
                    <div className="bg-muted mt-1.5 h-1.5 overflow-hidden rounded-full">
                      <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${t.pct}%` }}
                        transition={{ delay: 0.1 * i, duration: 0.7, ease: "easeOut" }}
                        className={t.covered ? "bg-primary h-full" : "bg-warning h-full"}
                      />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </AsyncSection>
          <div className="border-border mt-5 flex items-center justify-between border-t pt-4">
            <span className="text-muted-foreground text-sm">Overall coverage</span>
            <span className="text-xl font-semibold">
              {overallCoverage != null ? `${overallCoverage}%` : "—"}
            </span>
          </div>
        </div>
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-3">
        <div className="surface-card p-6 lg:col-span-2">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold">Recent generations</h2>
            <Button asChild variant="ghost" size="sm">
              <Link to="/history">
                View all <ArrowUpRight className="size-4" />
              </Link>
            </Button>
          </div>
          {recent.isPending && (
            <p className="text-muted-foreground mt-4 text-sm">Loading recent generations…</p>
          )}
          {recent.error && (
            <p role="alert" className="text-destructive mt-4 text-sm">
              Unable to load recent generations. {recent.error.message}
            </p>
          )}
          {!recent.isPending && !recent.error && history.length === 0 && (
            <p className="text-muted-foreground mt-4 text-sm">No generations yet.</p>
          )}
          <div className="mt-4 divide-y">
            {history.slice(0, 5).map((h) => (
              <div key={h.id} className="flex flex-wrap items-center gap-3 py-3">
                <span className="bg-primary/10 text-primary flex size-9 items-center justify-center rounded-xl">
                  <LayersIcon className="size-4" />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">
                    {h.agent} · {h.items} items
                  </p>
                  <p className="text-muted-foreground truncate text-xs">
                    {h.doc} · {h.date}
                  </p>
                </div>
                <ReviewBadge state={h.review} />
              </div>
            ))}
          </div>
        </div>

        <div className="surface-card p-6">
          <h2 className="text-lg font-semibold">Library snapshot</h2>
          {!adminStats.isPending && !adminStats.error && documents.length === 0 && (
            <p className="text-muted-foreground mt-4 text-sm">No documents uploaded.</p>
          )}
          <div className="mt-4 space-y-3">
            {documents.slice(0, 4).map((d) => (
              <Link
                key={d.id}
                to="/library"
                className="border-border hover:border-primary/40 block rounded-xl border p-3 transition-colors"
              >
                <p className="truncate text-sm font-medium">{d.title}</p>
                <p className="text-muted-foreground mt-0.5 text-xs">
                  {d.kind} · {d.pages != null ? `${d.pages} pages` : "—"} · {d.chunks} chunks ·{" "}
                  {d.status}
                </p>
              </Link>
            ))}
          </div>
      </div>

      {/* Student Management Section for Math Assistant */}
      <div className="mt-8 surface-card p-6" dir="rtl">
        <h2 className="text-xl font-bold mb-2">🎓 إدارة حسابات الطلاب والرموز السرية (PINs)</h2>
        <p className="text-muted-foreground text-sm mb-6">
          إضافة طلاب جدد، توليد الرمز السري PIN تلقائياً، وتحديد تواريخ بداية ونهاية الفصل الدراسي لتفعيل أو إيقاف الحساب تلقائياً.
        </p>
        <StudentAdminSection />
      </div>
    </AppShell>
  );
}

function StudentAdminSection() {
  const [students, setStudents] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [fullName, setFullName] = useState("");
  const [pinCode, setPinCode] = useState("");
  const [startDate, setStartDate] = useState(new Date().toISOString().split("T")[0]);
  const [endDate, setEndDate] = useState(new Date(Date.now() + 90 * 86400000).toISOString().split("T")[0]);

  const apiBase = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";
  const token = localStorage.getItem("sensei_access_token") || "";

  const fetchStudents = async () => {
    setLoading(true);
    try {
      const res = await fetch(`${apiBase}/admin/students`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setStudents(data);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStudents();
  }, []);

  const handleCreateStudent = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await fetch(`${apiBase}/admin/students`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          full_name: fullName,
          pin_code: pinCode || undefined,
          start_date: startDate,
          end_date: endDate,
        }),
      });
      if (res.ok) {
        const created = await res.json();
        alert(`تم إضافة الطالب بنجاح! الرمز السري: ${created.pin_code}`);
        setFullName("");
        setPinCode("");
        fetchStudents();
      } else {
        alert("فشل إضافة الطالب");
      }
    } catch (err) {
      alert("خطأ في الاتصال بالشبكة");
    }
  };

  const toggleStudent = async (studentId: string, currentActive: boolean) => {
    try {
      await fetch(`${apiBase}/admin/students/${studentId}/toggle?is_active=${!currentActive}`, {
        method: "PATCH",
        headers: { Authorization: `Bearer ${token}` },
      });
      fetchStudents();
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <div className="space-y-6">
      <form onSubmit={handleCreateStudent} className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5 bg-muted/30 p-4 rounded-xl">
        <div>
          <label className="text-xs font-semibold block mb-1">اسم الطالب بالكامل</label>
          <input
            type="text"
            required
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            placeholder="مثال: علي حسن"
            className="w-full border rounded-lg p-2 text-sm text-right bg-background"
          />
        </div>
        <div>
          <label className="text-xs font-semibold block mb-1">PIN Code (اختياري)</label>
          <input
            type="text"
            value={pinCode}
            onChange={(e) => setPinCode(e.target.value)}
            placeholder="توليد تلقائي"
            className="w-full border rounded-lg p-2 text-sm text-right bg-background"
          />
        </div>
        <div>
          <label className="text-xs font-semibold block mb-1">تاريخ بداية التفعيل</label>
          <input
            type="date"
            required
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            className="w-full border rounded-lg p-2 text-sm bg-background"
          />
        </div>
        <div>
          <label className="text-xs font-semibold block mb-1">تاريخ نهاية التفعيل</label>
          <input
            type="date"
            required
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            className="w-full border rounded-lg p-2 text-sm bg-background"
          />
        </div>
        <div className="flex items-end">
          <Button type="submit" className="w-full font-bold">
            ➕ إضافة الطالب
          </Button>
        </div>
      </form>

      <div className="overflow-x-auto">
        <table className="w-full text-right text-sm border-collapse">
          <thead>
            <tr className="border-b bg-muted/50">
              <th className="p-3">اسم الطالب</th>
              <th className="p-3">الرمز السري (PIN)</th>
              <th className="p-3">تاريخ البداية</th>
              <th className="p-3">تاريخ النهاية</th>
              <th className="p-3">الحالة الحالية</th>
              <th className="p-3">الإجراء</th>
            </tr>
          </thead>
          <tbody>
            {students.length === 0 ? (
              <tr>
                <td colSpan={6} className="p-4 text-center text-muted-foreground">
                  {loading ? "جاري التحميل..." : "لا يوجد طلاب مضافين حتى الآن."}
                </td>
              </tr>
            ) : (
              students.map((s) => (
                <tr key={s.id} className="border-b hover:bg-muted/20">
                  <td className="p-3 font-semibold">{s.full_name}</td>
                  <td className="p-3 font-mono bg-muted/40 rounded px-2">{s.pin_code}</td>
                  <td className="p-3">{s.start_date}</td>
                  <td className="p-3">{s.end_date}</td>
                  <td className="p-3">
                    {s.currently_active ? (
                      <span className="text-emerald-500 font-bold">🟢 نشط (ضمن الفترة)</span>
                    ) : (
                      <span className="text-rose-500 font-bold">🔴 غير نشط / منتهي</span>
                    )}
                  </td>
                  <td className="p-3">
                    <button
                      onClick={() => toggleStudent(s.id, s.is_active)}
                      className="px-3 py-1 text-xs border rounded-md hover:bg-accent"
                    >
                      {s.is_active ? "تعطيل" : "تفعيل"}
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

