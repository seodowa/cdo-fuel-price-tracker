import { describe, expect, it } from 'vitest';
import { ageLabel, joinRows, rankStations } from './dashboard-functions.ts';
import type { CategoryRow, CurrentPriceRow, ProductRow, StationRow } from './models/database.ts';
import type { PriceRow } from './models/dashboard.ts';

// Invented stations and products, never real data
const stations: StationRow[] = [
	{
		id: 1,
		street_address: '12 Sample St',
		brand: { name: 'Alpha Fuel' },
		barangay: { name: 'Lapu' }
	}
];
const products: ProductRow[] = [{ id: 10, name: 'Alpha Regular 91', category_id: 100 }];
const categories: CategoryRow[] = [{ id: 100, name: 'gasoline' }];
const price: CurrentPriceRow = {
	station_id: 1,
	product_id: 10,
	price: 62.45,
	reported_at: '2026-11-10',
	is_estimate: true
};

// Defaults for a ranking row, so each test only spells out what it is about
const row = (overrides: Partial<PriceRow>): PriceRow => ({
	stationId: 1,
	brand: 'Alpha Fuel',
	street: '12 Sample St',
	barangay: 'Lapu',
	product: 'Alpha Regular 91',
	category: 'gasoline',
	cents: 6245,
	reportedAt: '2026-11-10',
	isEstimate: false,
	...overrides
});

// Mixed stations and categories, deliberately out of price order
const rows: PriceRow[] = [
	// Station 4: one gasoline product, the most expensive
	row({
		stationId: 4,
		brand: 'Delta Oil',
		street: '3 Narra Ave',
		barangay: 'Carmen',
		product: 'Delta Super 91',
		cents: 6500
	}),
	// Station 1: two gasoline products, only Xtra Advance 91 at 6245 should be ranked
	row({ stationId: 1, product: 'Blaze 95', cents: 6810 }),
	row({ stationId: 1, product: 'Xtra Advance 91', cents: 6245 }),
	// Station 2: diesel only, so it must not appear in the gasoline or kerosene rankings
	row({
		stationId: 2,
		brand: 'Bravo Gas',
		street: '8 Molave St',
		barangay: 'Nazareth',
		product: 'Bravo Diesel',
		category: 'diesel',
		cents: 5890
	}),
	// Station 3: the cheapest gasoline, and the only kerosene
	row({
		stationId: 3,
		brand: 'Charlie Petrol',
		street: '21 Acacia Rd',
		barangay: 'Kauswagan',
		product: 'Charlie Unleaded 91',
		cents: 6120
	}),
	row({
		stationId: 3,
		brand: 'Charlie Petrol',
		street: '21 Acacia Rd',
		barangay: 'Kauswagan',
		product: 'Charlie Kerosene',
		category: 'kerosene',
		cents: 7050
	})
];

describe('joinRows', () => {
	it('joins a price to its station, product and category names', () => {
		expect(joinRows([price], stations, products, categories)).toEqual([
			{
				stationId: 1,
				brand: 'Alpha Fuel',
				street: '12 Sample St',
				barangay: 'Lapu',
				product: 'Alpha Regular 91',
				category: 'gasoline',
				cents: 6245,
				reportedAt: '2026-11-10',
				isEstimate: true
			}
		]);
	});

	it('rounds to whole centavos', () => {
		// 65.15 * 100 is 6515.000000000001 in floating point
		const [row] = joinRows([{ ...price, price: 65.15 }], stations, products, categories);
		expect(row.cents).toBe(6515);
	});

	it('throws when the station is missing', () => {
		expect(() => joinRows([{ ...price, station_id: 2 }], stations, products, categories)).toThrow();
	});

	it('throws when the product is missing', () => {
		expect(() =>
			joinRows([{ ...price, product_id: 11 }], stations, products, categories)
		).toThrow();
	});

	it('throws when the category is missing', () => {
		const orphan: ProductRow[] = [{ ...products[0], category_id: 101 }];
		expect(() => joinRows([price], stations, orphan, categories)).toThrow();
	});
});

describe('ageLabel', () => {
	it('says "Reported today" on the same day', () => {
		expect(ageLabel('2026-11-14', '2026-11-14')).toBe('Reported today');
	});

	it('says "Reported today" for a future date', () => {
		expect(ageLabel('2026-11-15', '2026-11-14')).toBe('Reported today');
	});

	it('says "Yesterday" after one day', () => {
		expect(ageLabel('2026-11-13', '2026-11-14')).toBe('Yesterday');
	});

	it('counts days after that', () => {
		expect(ageLabel('2026-11-02', '2026-11-14')).toBe('12 days ago');
	});

	it('counts across a month end', () => {
		expect(ageLabel('2026-02-27', '2026-03-01')).toBe('2 days ago');
	});

	it('counts across a year end', () => {
		expect(ageLabel('2026-12-31', '2027-01-02')).toBe('2 days ago');
	});
});

describe('rankStations', () => {
	it('ranks the cheapest price of gasoline', () => {
		expect(rankStations(rows, 'gasoline')).toEqual([
			{ ...rows[4], rank: 1 }, // Station 3, Charlie Unleaded 91 at 6120
			{ ...rows[2], rank: 2 }, // Station 1, Xtra Advance 91 at 6245 (Blaze 95 dropped)
			{ ...rows[0], rank: 3 } // Station 4, Delta Super 91 at 6500
		]);
	});

	it('leaves out stations without that category', () => {
		// Station 2 sells only diesel
		expect(rankStations(rows, 'kerosene')).toEqual([{ ...rows[5], rank: 1 }]);
	});

	// Each tie test lists the rows in the wrong order, so a passing test proves the sort moved them
	it('breaks same price by newer reportedAt', () => {
		const older = row({ stationId: 1, reportedAt: '2026-11-10' });
		const newer = row({ stationId: 2, reportedAt: '2026-11-12' });
		expect(rankStations([older, newer], 'gasoline')).toEqual([
			{ ...newer, rank: 1 },
			{ ...older, rank: 2 }
		]);
	});

	it('breaks same price and date by brand', () => {
		const bravo = row({ stationId: 1, brand: 'Bravo Gas' });
		const alpha = row({ stationId: 2, brand: 'Alpha Fuel' });
		expect(rankStations([bravo, alpha], 'gasoline')).toEqual([
			{ ...alpha, rank: 1 },
			{ ...bravo, rank: 2 }
		]);
	});

	it('breaks same price, date and brand by "{street}, {barangay}"', () => {
		const bamboo = row({ stationId: 1, street: '5 Bamboo St' });
		const acacia = row({ stationId: 2, street: '5 Acacia St' });
		expect(rankStations([bamboo, acacia], 'gasoline')).toEqual([
			{ ...acacia, rank: 1 },
			{ ...bamboo, rank: 2 }
		]);
	});

	it('keeps the smaller product name when one station has two products at the same price', () => {
		const xtra = row({ stationId: 1, product: 'Xtra Advance 91', cents: 6500 });
		const blaze = row({ stationId: 1, product: 'Blaze 95', cents: 6500 });
		expect(rankStations([xtra, blaze], 'gasoline')).toEqual([{ ...blaze, rank: 1 }]);
		expect(rankStations([blaze, xtra], 'gasoline')).toEqual([{ ...blaze, rank: 1 }]);
	});

	it('returns [] for no rows', () => {
		expect(rankStations([], 'gasoline')).toEqual([]);
	});
});
