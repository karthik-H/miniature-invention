const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normalizeEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  if (!EMAIL_PATTERN.test(email) || email.length > 254) return null;
  return email;
}

export function readPassword(value: unknown): string | null {
  if (typeof value !== "string") return null;
  if (value.length < 8 || value.length > 72) return null;
  return value;
}

export function readProductInput(body: unknown): {
  name: string;
  description: string;
  priceCents: number;
  sku: string;
} | { error: string } {
  if (!body || typeof body !== "object") {
    return { error: "Request body must be a JSON object" };
  }
  const record = body as Record<string, unknown>;

  if (typeof record.name !== "string" || record.name.trim().length === 0 || record.name.length > 200) {
    return { error: "name is required (1-200 characters)" };
  }
  if (typeof record.description !== "string" || record.description.length > 2000) {
    return { error: "description must be a string up to 2000 characters" };
  }
  if (!Number.isInteger(record.priceCents) || (record.priceCents as number) < 0) {
    return { error: "priceCents must be a non-negative integer" };
  }
  if (typeof record.sku !== "string" || !/^[A-Za-z0-9_-]{1,64}$/.test(record.sku)) {
    return { error: "sku must be 1-64 characters: letters, numbers, _ or -" };
  }

  return {
    name: record.name.trim(),
    description: record.description,
    priceCents: record.priceCents as number,
    sku: record.sku,
  };
}
