export function env(name: string): string | null {
  const v = process.env[name];
  return v && v.trim() ? v.trim() : null;
}
