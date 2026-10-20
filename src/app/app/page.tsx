import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { ensureSeed } from "@/db/seed";
import ChatApp from "@/components/chat/ChatApp";

export const dynamic = "force-dynamic";

export default async function AppPage() {
  await ensureSeed();
  const me = await getSessionUser();
  if (!me) redirect("/sign-in");
  return <ChatApp />;
}
