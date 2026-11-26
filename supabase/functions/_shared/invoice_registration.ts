// 登録番号の確認 (0229): an invoice's 登録番号 against 国税庁の適格請求書発行
// 事業者公表システム Web-API. Pure helpers: the number in its one form, the
// request, the answer read (defensively: a field missing is a field not
// known), and whether two company names are the same company.

export const NTA_HOST = "https://web-api.invoice-kohyo.nta.go.jp";

/** "T1234567890123" from what an invoice or a person wrote — full-width,
 * spaces, hyphens, a missing T; null when it is not 13 digits. */
export function normalizeRegNo(s: unknown): string | null {
  if (typeof s !== "string") return null;
  const t = s.normalize("NFKC").toUpperCase().replace(/[\s\-‐－ー_]/g, "");
  const m = /^T?(\d{13})$/.exec(t);
  return m ? `T${m[1]}` : null;
}

/** The lookup by number: at most 10 numbers a request, JSON (type 21),
 * the latest only (history 0). */
export function ntaRequestUrl(appId: string, numbers: string[]): string {
  const q = new URLSearchParams({ id: appId, number: numbers.join(","), type: "21", history: "0" });
  return `${NTA_HOST}/1/num?${q.toString()}`;
}

export type RegStatus = "valid" | "not_found" | "revoked" | "expired";

export type Registration = {
  number: string;
  status: RegStatus;
  name: string | null;
  kana: string | null;
  trade_name: string | null;
  address: string | null;
  kind: string | null;
  registration_date: string | null;
  disposal_date: string | null;
  expire_date: string | null;
  update_date: string | null;
  raw: Record<string, unknown> | null;
};

const str = (v: unknown): string | null => (typeof v === "string" && v.trim() ? v.trim() : null);
const day = (v: unknown): string | null => {
  const s = str(v);
  return s && /^\d{4}-\d{2}-\d{2}/.test(s) ? s.slice(0, 10) : null;
};

/** Each number asked, from the Web-API's answer: registered and in force,
 * not found, or ended (取消 = revoked, 失効 = expired). Where the answer
 * holds several entries for a number, the latest one counts. */
export function readNtaAnswer(json: unknown, asked: string[]): Registration[] {
  const list = json && typeof json === "object" && Array.isArray((json as Record<string, unknown>).announcement)
    ? ((json as Record<string, unknown>).announcement as Record<string, unknown>[])
    : [];
  const byNumber = new Map<string, Record<string, unknown>>();
  for (const a of list) {
    const n = normalizeRegNo(a.registratedNumber ?? a.registrationNumber ?? a.number);
    if (!n) continue;
    const prev = byNumber.get(n);
    // latest "1" wins; else the later sequence.
    if (!prev || a.latest === "1" || Number(a.sequenceNumber ?? 0) > Number(prev.sequenceNumber ?? 0)) {
      byNumber.set(n, a);
    }
  }
  return asked.map((number) => {
    const a = byNumber.get(number);
    if (!a) {
      return {
        number, status: "not_found", name: null, kana: null, trade_name: null, address: null, kind: null,
        registration_date: null, disposal_date: null, expire_date: null, update_date: null, raw: null,
      };
    }
    const disposal = day(a.disposalDate), expire = day(a.expireDate);
    const process = str(a.process);
    const status: RegStatus = disposal || process === "04" ? "revoked" : expire || process === "03" ? "expired" : "valid";
    return {
      number,
      status,
      name: str(a.name),
      kana: str(a.kana),
      trade_name: str(a.tradeName),
      address: str(a.address) ?? str(a.addressInside),
      kind: str(a.kind) === "1" ? "individual" : str(a.kind) === "2" ? "corporation" : str(a.kind),
      registration_date: day(a.registrationDate),
      disposal_date: disposal,
      expire_date: expire,
      update_date: day(a.updateDate),
      raw: a,
    };
  });
}

/** A company name as it can be compared: no 株式会社 and the like, no spaces
 * or punctuation, one width, one case. */
export function companyKey(s: string | null | undefined): string {
  return (s ?? "").normalize("NFKC").toUpperCase()
    .replace(/株式会社|有限会社|合同会社|合資会社|合名会社|一般社団法人|一般財団法人|\(株\)|\(有\)|\(同\)|㈱|㈲/g, "")
    .replace(/[\s・.,、。'"’()（）\-‐－ー]/g, "");
}

/** The same company, by name (one name holding the other counts: a shop
 * name, a branch). */
export function sameCompany(a: string | null | undefined, b: string | null | undefined): boolean {
  const x = companyKey(a), y = companyKey(b);
  if (!x || !y) return false;
  return x === y || (Math.min(x.length, y.length) >= 3 && (x.includes(y) || y.includes(x)));
}
