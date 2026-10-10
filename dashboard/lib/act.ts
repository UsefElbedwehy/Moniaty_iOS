import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";

type Err = { message: string } | null | undefined;

/** Finishes a server action: revalidates the page and redirects back with a flash message. */
export function done(path: string, error?: Err, okMessage = "تم الحفظ"): never {
  revalidatePath(path.split("?")[0]);
  const sep = path.includes("?") ? "&" : "?";
  redirect(`${path}${sep}${error ? `err=${encodeURIComponent(error.message)}` : `ok=${encodeURIComponent(okMessage)}`}`);
}

/** RPCs answer `{ok:false, error}` for business refusals; turn those into an error too. */
export function rpcError(result: { data: unknown; error: Err }): Err {
  if (result.error) return result.error;
  const data = result.data as { ok?: boolean; error?: string } | null;
  if (data && data.ok === false) return { message: data.error ?? "refused" };
  return null;
}

export const str = (form: FormData, key: string) => String(form.get(key) ?? "").trim();
export const optStr = (form: FormData, key: string) => str(form, key) || null;
export const bool = (form: FormData, key: string) => form.get(key) === "on" || form.get(key) === "true";
export const num = (form: FormData, key: string) => Number(str(form, key) || 0);
