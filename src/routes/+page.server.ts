import { dev } from '$app/env';
import { error } from '@sveltejs/kit';
import { mockPriceRows } from '#lib/mock-data/price-rows.ts';
import type { PageServerLoad } from './$types';

// Temporary stand-in until the Supabase load is built. It serves invented mock rows in
// development only; anywhere else it fails like a broken read, so mock prices under real brand
// names can never reach a visitor.
export const load: PageServerLoad = async () => {
	if (!dev) error(503, "Prices couldn't load. Try again later.");

	return {
		today: new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Manila' }).format(new Date()),
		categories: ['diesel', 'gasoline', 'kerosene'],
		rows: mockPriceRows
	};
};
