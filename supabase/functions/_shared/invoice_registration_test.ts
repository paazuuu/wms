import { assertEquals } from "jsr:@std/assert";
import { companyKey, normalizeRegNo, ntaRequestUrl, readNtaAnswer, sameCompany } from "./invoice_registration.ts";

Deno.test("登録番号 in its one form", () => {
  assertEquals(normalizeRegNo("T1234567890123"), "T1234567890123");
  assertEquals(normalizeRegNo("ｔ１２３４－５６７８－９０１２３"), "T1234567890123");
  assertEquals(normalizeRegNo("1234567890123"), "T1234567890123");
  assertEquals(normalizeRegNo("T123"), null);
  assertEquals(normalizeRegNo(null), null);
});

Deno.test("the request: JSON, latest only, numbers joined", () => {
  assertEquals(ntaRequestUrl("APP", ["T1234567890123", "T2222222222222"]),
    "https://web-api.invoice-kohyo.nta.go.jp/1/num?id=APP&number=T1234567890123%2CT2222222222222&type=21&history=0");
});

Deno.test("the answer read: in force, ended, not found (0229)", () => {
  const r = readNtaAnswer({
    count: "3",
    announcement: [
      { sequenceNumber: "1", registratedNumber: "T1111111111111", process: "01", kind: "2", latest: "1",
        registrationDate: "2023-10-01", name: "テスト商事株式会社", address: "大阪府大阪市中央区テスト1-2-3" },
      { sequenceNumber: "2", registratedNumber: "T2222222222222", process: "04", kind: "2", latest: "1",
        registrationDate: "2023-10-01", disposalDate: "2025-04-01", name: "テスト物産株式会社" },
      { sequenceNumber: "3", registratedNumber: "T3333333333333", process: "03", kind: "1", latest: "1",
        expireDate: "2025-12-31", name: "テスト 太郎" },
    ],
  }, ["T1111111111111", "T2222222222222", "T3333333333333", "T4444444444444"]);
  assertEquals(r.map((x) => [x.number, x.status, x.kind]), [
    ["T1111111111111", "valid", "corporation"],
    ["T2222222222222", "revoked", "corporation"],
    ["T3333333333333", "expired", "individual"],
    ["T4444444444444", "not_found", null],
  ]);
  assertEquals(r[0].name, "テスト商事株式会社");
  assertEquals(r[0].registration_date, "2023-10-01");
  assertEquals(readNtaAnswer({}, ["T1111111111111"])[0].status, "not_found");
});

Deno.test("the same company by name", () => {
  assertEquals(companyKey("株式会社 テスト商事"), "テスト商事");
  assertEquals(sameCompany("テスト商事株式会社", "㈱テスト商事"), true);
  assertEquals(sameCompany("テスト商事株式会社 大阪支店", "テスト商事株式会社"), true);
  assertEquals(sameCompany("テスト商事株式会社", "テスト物産株式会社"), false);
  assertEquals(sameCompany("", "テスト商事"), false);
});
