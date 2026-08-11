/**
 * Generate a deterministic ASCII-safe category slug for R2 prefixes.
 * Slugs are ALWAYS generated server-side from a verified category name.
 */
export function slugifyCategoryName(raw: string): string {
  const lowered = raw.trim().toLowerCase();

  // Prefer ASCII-safe output for predictable object keys.
  const ascii = lowered
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");

  if (ascii.length > 0) {
    return ascii;
  }

  // Fallback when the name has no ASCII letters/digits.
  return "category";
}
