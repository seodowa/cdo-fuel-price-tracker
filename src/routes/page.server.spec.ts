import { isHttpError } from '@sveltejs/kit';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { load } from './+page.server.ts';

type Call = {
	table: string;
	select: string | null;
	eq: unknown[];
	lte: unknown[];
	order: unknown[];
	limit: number | null;
};
type Response = { data: unknown[] | null; error: { code: string } | null };

// vi.mock factories are hoisted above the imports, so the state they share must be hoisted too
const fake = vi.hoisted(() => ({
	calls: [] as Call[],
	responses: {} as Record<string, Response>,
	key: 'invented-publishable-key'
}));

vi.mock('$app/env/private', () => ({
	SUPABASE_URL: 'http://127.0.0.1:54321',
	SUPABASE_PUBLISHABLE_KEY: fake.key
}));

// Records every query and answers with the response set for its table
vi.mock('@supabase/supabase-js', () => ({
	createClient: () => ({
		from(table: string) {
			const call: Call = { table, select: null, eq: [], lte: [], order: [], limit: null };
			fake.calls.push(call);
			const builder = {
				select(cols: string) {
					call.select = cols;
					return builder;
				},
				eq(...args: unknown[]) {
					call.eq = args;
					return builder;
				},
				lte(...args: unknown[]) {
					call.lte = args;
					return builder;
				},
				order(...args: unknown[]) {
					call.order = args;
					return builder;
				},
				limit(n: number) {
					call.limit = n;
					return builder;
				},
				then(resolve: (value: Response) => unknown, reject: (reason: unknown) => unknown) {
					return Promise.resolve(fake.responses[table]).then(resolve, reject);
				}
			};
			return builder;
		}
	})
}));

// Invented data, no real stations
const categories = [
	{ id: 1, name: 'diesel' },
	{ id: 2, name: 'gasoline' },
	{ id: 3, name: 'kerosene' }
];
const station = {
	id: 10,
	street_address: '12 Sample St',
	brand: { name: 'Brand A' },
	barangay: { name: 'Testville' }
};
const product = { id: 100, name: 'Sample Unleaded 91', category_id: 2 };
const price = {
	station_id: 10,
	product_id: 100,
	price: 62.45,
	reported_at: '2026-11-10',
	is_estimate: true
};

const reads = ['current_price', 'station', 'fuel_product', 'fuel_category'] as const;
const validRows: Record<(typeof reads)[number], unknown> = {
	current_price: price,
	station,
	fuel_product: product,
	fuel_category: categories[0]
};

function respondWithValidData() {
	fake.responses = {
		current_price: { data: [price], error: null },
		station: { data: [station], error: null },
		fuel_product: { data: [product], error: null },
		fuel_category: { data: categories, error: null }
	};
}

const event = {} as Parameters<typeof load>[0];

async function expectLoadFailure() {
	// PageServerLoad may return a plain value or a promise; Promise.resolve gives .then either way
	const failure = await Promise.resolve(load(event)).then(
		() => null,
		(e: unknown) => e
	);
	expect(isHttpError(failure, 503)).toBe(true);
	if (isHttpError(failure)) {
		expect(failure.body.message).toBe("Prices couldn't load. Try again later.");
	}
}

describe('load', () => {
	let consoleError: ReturnType<typeof vi.spyOn>;

	beforeEach(() => {
		fake.calls.length = 0;
		respondWithValidData();
		consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
	});

	afterEach(() => {
		// The server log may name the table and error code, never the key (research R11)
		expect(JSON.stringify(consoleError.mock.calls)).not.toContain(fake.key);
		vi.restoreAllMocks();
		vi.useRealTimers();
	});

	it('(a) returns the Manila date, the categories and the joined rows', async () => {
		vi.useFakeTimers({ toFake: ['Date'] });
		// 17:00 UTC on the 11th is 01:00 on the 12th in Manila
		vi.setSystemTime(new Date('2026-11-11T17:00:00Z'));

		const result = await load(event);

		expect(result).toMatchObject({
			today: '2026-11-12',
			categories: ['diesel', 'gasoline', 'kerosene'],
			rows: [
				{
					stationId: 10,
					brand: 'Brand A',
					street: '12 Sample St',
					barangay: 'Testville',
					product: 'Sample Unleaded 91',
					category: 'gasoline',
					cents: 6245,
					reportedAt: '2026-11-10',
					isEstimate: true
				}
			]
		});
	});

	it('(b) reads only the contract columns and no private tables', async () => {
		await load(event);

		const selectOf = (table: string) => fake.calls.find((c) => c.table === table)?.select;
		expect(selectOf('current_price')).toBe(
			'station_id, product_id, price, reported_at, is_estimate'
		);
		expect(selectOf('station')).toBe('id, street_address, brand(name), barangay(name)');
		expect(selectOf('fuel_product')).toBe('id, name, category_id');
		expect(selectOf('fuel_category')).toBe('id, name');
		expect(fake.calls.find((c) => c.table === 'fuel_category')?.order).toEqual(['name']);

		// price_shift is allowed by the contract and arrives with US2 (T033)
		const allowed = [...reads, 'price_shift'];
		for (const call of fake.calls) {
			expect(allowed).toContain(call.table);
		}
	});

	it('(c) a query error gives the 503 page', async () => {
		fake.responses.current_price = { data: null, error: { code: 'X' } };

		await expectLoadFailure();
	});

	for (const table of reads) {
		it(`(d) ${table} at the 1000-row cap gives the 503 page`, async () => {
			fake.responses[table] = {
				data: Array.from({ length: 1000 }, () => validRows[table]),
				error: null
			};

			await expectLoadFailure();
		});
	}

	it('(e) a price whose station is missing gives the 503 page', async () => {
		fake.responses.station = { data: [], error: null };

		await expectLoadFailure();
	});
});
