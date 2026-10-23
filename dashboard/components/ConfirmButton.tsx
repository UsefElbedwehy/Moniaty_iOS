"use client";

/** A submit button that asks for confirmation first (destructive admin actions). `formAction`
 *  submits the surrounding form to a different server action. */
export function ConfirmButton({ message, children, className, formAction }: {
  message: string; children: React.ReactNode; className?: string; formAction?: (form: FormData) => void | Promise<void>;
}) {
  return (
    <button type="submit" className={className} formAction={formAction} formNoValidate={!!formAction}
      onClick={(e) => { if (!confirm(message)) e.preventDefault(); }}>
      {children}
    </button>
  );
}
