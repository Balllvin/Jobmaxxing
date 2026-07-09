export function normalizeExternalUrl(value: string | undefined): string {
  const trimmed = value?.trim() ?? "";
  if (!trimmed) {
    return "";
  }

  const candidate = /^[a-z][a-z0-9+.-]*:/i.test(trimmed) ? trimmed : `https://${trimmed}`;
  let parsed: URL;
  try {
    parsed = new URL(candidate);
  } catch {
    throw new Error(`Invalid URL: ${trimmed}`);
  }

  if (!["http:", "https:"].includes(parsed.protocol)) {
    throw new Error(`Unsupported URL scheme: ${parsed.protocol.replace(":", "")}`);
  }
  if (!parsed.hostname) {
    throw new Error(`Invalid URL: ${trimmed}`);
  }
  return parsed.toString();
}

export function isSafeExternalUrl(value: string | undefined): boolean {
  try {
    normalizeExternalUrl(value);
    return true;
  } catch {
    return false;
  }
}
