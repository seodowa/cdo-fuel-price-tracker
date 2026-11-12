# Contract: Public Dashboard

## Routes

| Path                    | Data                                            | Content                                                         |
| ----------------------- | ----------------------------------------------- | --------------------------------------------------------------- |
| `/`                     | `+page.server.ts` load (data-model "Page data") | Dashboard. Query: `fuel`, `page`                                |
| `/analytics`            | none                                            | `<h1>Analytics</h1>`, "Coming soon"                             |
| `/contribute`           | none                                            | `<h1>Contribute</h1>`, "Coming soon"                            |
| any load failure on `/` | status 503                                      | "Prices couldn't load. Try again later." and a "Try again" link |

No route takes input other than the `fuel` and `page` query parameters. Both are matched against
known values (data-model "URL state") and never echoed raw.

## Data reads (001 `contracts/data-api.md`, anon role)

| Object          | Columns                                                                                      |
| --------------- | -------------------------------------------------------------------------------------------- |
| `current_price` | `station_id, product_id, price, reported_at, is_estimate`                                    |
| `station`       | `id, street_address`, embedded `brand(name)`, `barangay(name)`                               |
| `fuel_product`  | `id, name, category_id`                                                                      |
| `fuel_category` | `id, name`                                                                                   |
| `price_shift`   | `brand_id, amount, effective_on`, filtered `category_id=eq.{id}`, `effective_on=lte.{today}` |

Never selected: `price_report` (any column), `submission`, `profile`, `admin_log`.

## Pure functions (`src/lib/dashboard.ts`)

```ts
joinRows(prices, stations, products, categories): PriceRow[]   // throws on a missing station, product or category
ageLabel(reportedAt: string, today: string): string             // "Reported today" | "Yesterday" | "N days ago"
rankStations(rows: PriceRow[], category: string): RankedRow[]
paginate(ranked: RankedRow[], pageParam: string | null): Page
averageCents(ranked: RankedRow[]): number | null
formatCents(cents: number): string                              // 6245 -> "62.45"
summarizeShifts(shifts: { brand_id: number; amount: number; effective_on: string }[]): Adjustment
formatAdjustment(a: Adjustment): { arrow: string; amount: string; word: string }
formatDate(date: string): string                                // "2026-10-27" -> "Oct 27, 2026"
```

Parameter shapes for `joinRows` are the source rows in `data-model.md`. Each function has Vitest
cases in `src/lib/dashboard.spec.ts`, written before it.

## Displayed text (fixed strings)

| Place             | Text                                                                                                               |
| ----------------- | ------------------------------------------------------------------------------------------------------------------ |
| App name          | CDO Fuel Price Tracker                                                                                             |
| Tabs              | Dashboard, Analytics, Contribute                                                                                   |
| Mode button label | Switch to light mode / Switch to dark mode                                                                         |
| Menu button label | Menu                                                                                                               |
| Ranking title     | Station ranking                                                                                                    |
| Ranking row       | brand, then `{street}, {barangay} · {age}` plus ` · est.` when estimated, product name beside the price            |
| Legend            | est. = reported price plus weekly adjustments since then                                                           |
| Footer            | City avg ₱{avg} · bars scaled to highest price                                                                     |
| Pagination        | ‹ Prev, Page N of M, Next ›                                                                                        |
| Adjustment card   | PRICE ADJUSTMENT, As of {Mon D, YYYY}, Change per litre vs. previous week                                          |
| Cheapest card     | CHEAPEST IN CDO. Per fuel: fuel name, `{brand} · {barangay} · {age}` plus ` · est.`, product name beside the price |
| Empty             | No prices reported yet                                                                                             |
| Error             | Prices couldn't load. Try again later.                                                                             |
| Coming soon pages | Coming soon                                                                                                        |
