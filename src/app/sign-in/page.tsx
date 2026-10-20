import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { AuthShell, SignInForm } from "@/components/auth/AuthPanels";

export const dynamic = "force-dynamic";

export default async function SignInPage() {
  const me = await getSessionUser();
  if (me) redirect("/app");

  return (
    <AuthShell
      title="Welcome back"
      subtitle="Sign in — every message and voice note will render in your language."
    >
      <SignInForm />
    </AuthShell>
  );
}
