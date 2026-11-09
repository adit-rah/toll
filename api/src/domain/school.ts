// "cs.uwaterloo.ca" → ["cs.uwaterloo.ca", "uwaterloo.ca"]: departments and subdomains belong to the school
// whose domain they end in. Single labels ("ca") are never a school.
export function domainCandidates(email: string): string[] {
  const domain = email.trim().toLowerCase().split("@")[1] ?? "";
  const labels = domain.split(".").filter(Boolean);
  const out: string[] = [];
  for (let i = 0; i <= labels.length - 2; i++) out.push(labels.slice(i).join("."));
  return out;
}
