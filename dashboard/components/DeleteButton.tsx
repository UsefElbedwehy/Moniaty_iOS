"use client";

/** Permanent delete: asks the admin to type «حذف» / DELETE, which the server checks again. */
export function DeleteButton({ label, prompt, formAction }: {
  label: string; prompt: string; formAction: (form: FormData) => void | Promise<void>;
}) {
  return (
    <button type="submit" className="danger" formAction={formAction} formNoValidate
      onClick={(e) => {
        const typed = window.prompt(prompt);
        if (!typed) { e.preventDefault(); return; }
        const form = e.currentTarget.form;
        const input = form?.querySelector<HTMLInputElement>('input[name="confirm"]');
        if (input) input.value = typed.trim();
      }}>
      {label}
    </button>
  );
}
