# Data Model: Public Dashboard

No database change. The 001 tables and the `current_price` view are read as they are
(`specs/001-database-schema/data-model.md`). This file defines the TypeScript shapes the load
function and the pure functions in `src/lib/dashboard.ts` pass around. Money is integer centavos
(research R4). Dates are `YYYY-MM-DD` strings (research R3).

## Source rows (from PostgREST, research R1)

| Shape               | Fields                                                                                                                     |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `current_price` row | `station_id: number`, `product_id: number`, `price: number` (₱, 2 decimals), `reported_at: string`, `is_estimate: boolean` |
| `station` row       | `id: number`, `street_address: string` (1 to 200 chars), `brand: { name: string }`, `barangay: { name: string }`           |
| `fuel_product` row  | `id: number`, `name: string` (1 to 100 chars), `category_id: number`                                                       |
| `fuel_category` row | `id: number`, `name: string` (seed: `diesel`, `gasoline`, `kerosene`)                                                      |
| `price_shift` row   | `brand_id: number`, `amount: number` (₱, `between -20 and 20`), `effective_on: string`                                     |

## `PriceRow` (built by `joinRows` in the load function, one per `current_price` row)

| Field        | Type      | From                                                |
| ------------ | --------- | --------------------------------------------------- |
| `stationId`  | `number`  | `current_price.station_id`                          |
| `brand`      | `string`  | `station.brand.name`                                |
| `street`     | `string`  | `station.street_address`                            |
| `barangay`   | `string`  | `station.barangay.name`                             |
| `product`    | `string`  | `fuel_product.name`                                 |
| `category`   | `string`  | `fuel_category.name` via `fuel_product.category_id` |
| `cents`      | `number`  | `Math.round(current_price.price * 100)`             |
| `reportedAt` | `string`  | `current_price.reported_at`                         |
| `isEstimate` | `boolean` | `current_price.is_estimate`                         |

A `current_price` row whose station, product or category is missing from the other responses
makes `joinRows` throw, which the load turns into the FR-014 error page (R11), never a silent skip.

Displayed location: ranking "{street}, {barangay}", "Cheapest in CDO" "{brand} · {barangay}"
(D16). Tie-break key: "{street}, {barangay}".

## `RankedRow` (output of `rankStations`)

`PriceRow` plus `rank: number` (1-based, across all pages). One per station per category: the
station's cheapest product in that category (D3). Order and ties: research R5.

## `Page` (output of `paginate`)

`{ rows: RankedRow[]; page: number; pages: number }`. 10 rows per page, `pages ≥ 1`, `page` in
1 .. `pages`.

## `Adjustment` (output of `summarizeShifts`, one per category)

| `kind`      | Extra fields                                                       | Shown as                                  |
| ----------- | ------------------------------------------------------------------ | ----------------------------------------- |
| `none`      | none                                                               | "No adjustment recorded yet"              |
| `no-change` | `asOf`                                                             | "No change"                               |
| `mixed`     | `asOf`                                                             | "Mixed"                                   |
| `increase`  | `asOf`, `minCents`, `maxCents` (≥ 0, `min ≤ max`)                  | "▲ +₱max" or "▲ +₱min – ₱max", "Increase" |
| `rollback`  | `asOf`, `minCents`, `maxCents` (absolute values, ≥ 0, `min ≤ max`) | "▼ −₱max" or "▼ −₱min – ₱max", "Rollback" |

Rules: research R6.

## Page data (returned by `src/routes/+page.server.ts`)

| Field         | Type                                                                         |
| ------------- | ---------------------------------------------------------------------------- |
| `today`       | `string` (Manila date)                                                       |
| `categories`  | `string[]`, sorted by name                                                   |
| `rows`        | `PriceRow[]`                                                                 |
| `adjustments` | `{ category: string; adjustment: Adjustment }[]`, same order as `categories` |

## URL state (read by `src/routes/+page.svelte`, research R2)

| Param  | Values                  | Default / invalid         |
| ------ | ----------------------- | ------------------------- |
| `fuel` | a name in `categories`  | `gasoline`                |
| `page` | integer 1 .. page count | 1, and clamped into range |

Page size: 10 (D11).

## Mode preference

`localStorage['theme']`: `'light'` or `'dark'`. Any other value or blocked storage means "follow
the device" (research R8). Stays in the visitor's browser only.
