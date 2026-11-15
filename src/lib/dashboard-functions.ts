import type { CategoryRow, CurrentPriceRow, ProductRow, StationRow } from './models/database.ts';
import type { PriceRow, RankedRow } from './models/dashboard.ts';

// Joins each current price to its station, product and category names. A missing lookup means
// the database broke a foreign key, so it throws instead of showing a half-empty row.
export function joinRows(
	prices: CurrentPriceRow[],
	stations: StationRow[],
	products: ProductRow[],
	categories: CategoryRow[]
): PriceRow[] {
	const stationById = new Map(stations.map((s) => [s.id, s]));
	const productById = new Map(products.map((p) => [p.id, p]));
	const categoryById = new Map(categories.map((c) => [c.id, c]));

	return prices.map((price) => {
		const station = stationById.get(price.station_id);
		if (!station) throw new Error(`No station ${price.station_id}`);
		const product = productById.get(price.product_id);
		if (!product) throw new Error(`No product ${price.product_id}`);
		const category = categoryById.get(product.category_id);
		if (!category) throw new Error(`No category ${product.category_id}`);

		return {
			stationId: station.id,
			brand: station.brand.name,
			street: station.street_address,
			barangay: station.barangay.name,
			product: product.name,
			category: category.name,
			// Whole centavos, so later sums and averages don't drift (65.15 * 100 is 6515.000000000001)
			cents: Math.round(price.price * 100),
			reportedAt: price.reported_at,
			isEstimate: price.is_estimate
		};
	});
}

// Whole calendar days from reportedAt to today, both 'YYYY-MM-DD'. Date.UTC keeps the device's
// time zone and daylight saving out of the count.
export function ageLabel(reportedAt: string, today: string): string {
	const day = (date: string) => {
		const [y, m, d] = date.split('-').map(Number);
		return Date.UTC(y, m - 1, d); // Months count from 0
	};
	// 24 hours × 60 minutes × 60 seconds × 1000 ms = 86,400,000 ms in one day
	const days = Math.round((day(today) - day(reportedAt)) / 86_400_000);

	if (days <= 0) return 'Reported today';
	if (days === 1) return 'Yesterday';
	return `${days} days ago`;
}


export function rankStations(rows: PriceRow[], category: string): RankedRow[] {
	return rows.map( (row) => {
		return {
			...row,
			rank: 1
		}
	});
}
