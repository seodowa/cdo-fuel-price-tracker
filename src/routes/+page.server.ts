import { createClient } from '@supabase/supabase-js';
import { error } from '@sveltejs/kit';
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from '$app/env/private';
import { joinRows } from '#lib/dashboard-functions.ts';
import type { CategoryRow, CurrentPriceRow, ProductRow, StationRow } from '#lib/models/database.ts';
import type { PageServerLoad } from './$types';

// One client for every request: it never signs in, so there is no session to keep apart
const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
	auth: { persistSession: false }
});

// Supabase returns at most this many rows per read (max_rows in supabase/config.toml)
// ponytail: 1000-row ceiling per read, add .range() paging when the city passes ~250 stations
const MAX_ROWS = 1000;

// The rows of one read. An error, or a full response that may have been cut off, fails the load,
// so a partial list can never produce a wrong ranking
function rowsOf<T>(table: string, result: { data: unknown; error: { code: string } | null }): T[] {
	if (result.error || !Array.isArray(result.data)) {
		throw new Error(`${table} read failed: ${result.error?.code ?? 'no data'}`);
	}
	if (result.data.length >= MAX_ROWS) throw new Error(`${table} read hit the ${MAX_ROWS}-row cap`);
	return result.data as T[];
}

// Does not read `url`, so changing ?fuel= or ?page= doesn't rerun it; the page handles those
export const load: PageServerLoad = async () => {
	const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Manila' }).format(new Date());

	try {
		const [prices, stations, products, categories] = await Promise.all([
			supabase
				.from('current_price')
				.select('station_id, product_id, price, reported_at, is_estimate'),
			supabase.from('station').select('id, street_address, brand(name), barangay(name)'),
			supabase.from('fuel_product').select('id, name, category_id'),
			supabase.from('fuel_category').select('id, name').order('name')
		]);

		const categoryRows = rowsOf<CategoryRow>('fuel_category', categories);

		return {
			today,
			categories: categoryRows.map((c) => c.name),
			rows: joinRows(
				rowsOf<CurrentPriceRow>('current_price', prices),
				rowsOf<StationRow>('station', stations),
				rowsOf<ProductRow>('fuel_product', products),
				categoryRows
			)
		};
	} catch (e) {
		// Table and error code only; the key never appears in these messages
		console.error('Dashboard load failed:', e instanceof Error ? e.message : e);
	}

	// Outside the try: error() throws, and the catch above would swallow it
	error(503, "Prices couldn't load. Try again later.");
};
