import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { SUPPORTED_LANGUAGES } from "@/lib/i18n/languages";
import { AuthShell, RegisterForm } from "@/components/auth/AuthPanels";

export const dynamic = "force-dynamic";

export default async function RegisterPage() {
  const me = await getSessionUser();
  if (me) redirect("/app");

  const languages = SUPPORTED_LANGUAGES.map((l) => ({
    code: l.code,
    name: l.name,
    nativeName: l.nativeName,
    status: l.status,
  }));

  return (
    <AuthShell
      title="Create your account"
      subtitle="Choose your language once — UniCom renders everything in it from then on."
    >
      <RegisterForm languages={languages} />
    </AuthShell>
  );
}
