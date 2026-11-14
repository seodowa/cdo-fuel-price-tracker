import { describe, expect, it } from 'vitest';
import { ageLabel, joinRows } from './dashboard-functions.ts';
import type { CategoryRow, CurrentPriceRow, ProductRow, StationRow } from './models/database.ts';

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
