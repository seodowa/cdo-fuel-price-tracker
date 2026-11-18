import { execFileSync } from 'node:child_process';
import { expect, test } from '@playwright/test';

// The fixtures truncate tables, so they may only ever run against the local database
function databaseUrl(): string {
	process.loadEnvFile('.env');
	const url = process.env.SUPABASE_DB_URL;
	if (!url) throw new Error('SUPABASE_DB_URL is not set in .env');
	if (new URL(url).hostname !== '127.0.0.1') {
		throw new Error('SUPABASE_DB_URL must point at the local database (127.0.0.1)');
	}
	return url;
}

// Arguments go as an array, so no shell ever reads them
function loadFixtures(...names: string[]) {
	const url = databaseUrl();
	for (const name of names) {
		execFileSync('psql', [url, '-v', 'ON_ERROR_STOP=1', '-f', `supabase/fixtures/${name}.sql`], {
			stdio: 'pipe'
		});
	}
}

// Each test builds on the data the one before it loaded
test.describe.configure({ mode: 'serial' });

test('(1) with no prices, the ranking and Cheapest in CDO say "No prices reported yet"', async ({
	page
}) => {
	loadFixtures('empty');
	await page.goto('/');

	await expect(page.getByRole('link', { name: 'gasoline', exact: true })).toHaveAttribute(
		'aria-current',
		'true'
	);

	const ranking = page.getByRole('region', { name: 'Station ranking' });
	await expect(ranking.getByText('No prices reported yet')).toBeVisible();

	const cheapest = page.getByRole('region', { name: 'Cheapest in CDO' });
	await expect(cheapest.getByText('No prices reported yet')).toHaveCount(3);
});

test('(2) opens on the first page of the gasoline ranking, cheapest first', async ({ page }) => {
	loadFixtures('empty', 'dashboard');
	await page.goto('/');

	await expect(page.getByRole('link', { name: 'gasoline', exact: true })).toHaveAttribute(
		'aria-current',
		'true'
	);

	const rows = page.getByRole('list', { name: 'Station ranking' }).getByRole('listitem');
	await expect(rows).toHaveCount(5);
	await expect(page.getByText('Page 1 of 3')).toBeVisible();

	// Phoenix Bugo: 61.70 reported 8 days ago, minus this week's Phoenix gasoline rollback of 0.65
	await expect(rows.first()).toContainText('₱61.05');
});

test('(3) a station with two gasoline products appears once, at its cheaper one', async ({
	page
}) => {
	loadFixtures('empty', 'dashboard');
	await page.goto('/?page=2');

	const rows = page
		.getByRole('list', { name: 'Station ranking' })
		.getByRole('listitem')
		.filter({ hasText: 'Lapasan' });

	await expect(rows).toHaveCount(1);
	await expect(rows).toContainText('₱62.45');
	await expect(rows).toContainText('Xtra Advance');
	await expect(rows).not.toContainText('XCS');
});

// Gasoline page 2 holds ranks 6 to 10: Petron Lapasan, Petron Macasandig, Petron Bulua, Shell
// Carmen, Petron Agusan
test('(4) rows show their age, "est." only for shifted prices, and the legend', async ({
	page
}) => {
	loadFixtures('empty', 'dashboard');
	await page.goto('/?page=2');
	const rows = page.getByRole('list', { name: 'Station ranking' }).getByRole('listitem');

	const today = rows.filter({ hasText: 'Macasandig' });
	await expect(today).toContainText('Reported today');
	await expect(today).not.toContainText('est.');

	// Reported 12 days ago, before this week's Petron gasoline rollback: 63.50 - 0.85
	const shifted = rows.filter({ hasText: 'Bulua' });
	await expect(shifted).toContainText('12 days ago · est.');
	await expect(shifted).toContainText('₱62.65');

	await expect(
		page.getByText('est. = reported price plus weekly adjustments since then')
	).toBeVisible();
});

test('(5) the footer shows the city average of every ranked gasoline price', async ({ page }) => {
	loadFixtures('empty', 'dashboard');
	await page.goto('/');

	// The 15 ranked gasoline prices in centavos (shifted where "est."), summed by hand:
	// 6105 + 6120 + 6180 + 6195 + 6230 + 6245 + 6260 + 6265 + 6285 + 6290
	// + 6305 + 6340 + 6380 + 6715 + 6840 = 94755, and 94755 / 15 = 6317
	await expect(page.getByText('City avg ₱63.17')).toBeVisible();
});

test('(6) Next on page 2 shows the last 5 stations and no Next link', async ({ page }) => {
	loadFixtures('empty', 'dashboard');
	await page.goto('/?page=2');

	await page.getByRole('link', { name: 'Next' }).click();

	await expect(page).toHaveURL(/page=3/);
	await expect(page.getByText('Page 3 of 3')).toBeVisible();
	const rows = page.getByRole('list', { name: 'Station ranking' }).getByRole('listitem');
	await expect(rows).toHaveCount(5);
	// Rank 11 is Shell Gusa at 63.05
	await expect(rows.first()).toContainText('₱63.05');
	await expect(page.getByRole('link', { name: 'Next' })).toHaveCount(0);
});

test('(7) the Diesel link re-ranks by diesel price and is marked selected', async ({ page }) => {
	loadFixtures('empty', 'dashboard');
	await page.goto('/');

	await page.getByRole('link', { name: 'diesel', exact: true }).click();

	await expect(page).toHaveURL(/fuel=diesel/);
	await expect(page.getByRole('link', { name: 'diesel', exact: true })).toHaveAttribute(
		'aria-current',
		'true'
	);
	await expect(page.getByRole('link', { name: 'gasoline', exact: true })).not.toHaveAttribute(
		'aria-current'
	);
	// Cheapest diesel is Unioil Balulang at 55.35, reported this week so no shift applies
	const rows = page.getByRole('list', { name: 'Station ranking' }).getByRole('listitem');
	await expect(rows.first()).toContainText('₱55.35');
	await expect(page.getByText('Page 1 of 2')).toBeVisible();
});

test('(8) an unknown fuel in the URL falls back to gasoline', async ({ page }) => {
	loadFixtures('empty', 'dashboard');
	await page.goto('/?fuel=petrol');

	await expect(page.getByRole('link', { name: 'gasoline', exact: true })).toHaveAttribute(
		'aria-current',
		'true'
	);
	const rows = page.getByRole('list', { name: 'Station ranking' }).getByRole('listitem');
	await expect(rows.first()).toContainText('₱61.05');
});

test('(9) Cheapest in CDO shows the cheapest station for each fuel', async ({ page }) => {
	loadFixtures('empty', 'dashboard');
	await page.goto('/');
	const cheapest = page.getByRole('region', { name: 'Cheapest in CDO' });

	// Gasoline: Phoenix Bugo, 61.70 reported 8 days ago, minus the Phoenix rollback of 0.65
	await expect(cheapest.getByText('Phoenix · Bugo · 8 days ago · est.')).toBeVisible();
	await expect(cheapest).toContainText('₱61.05');
	await expect(cheapest).toContainText('Super Regular 91');

	// Diesel and kerosene are reported this week, so their age depends on the weekday and they
	// carry no "est."
	const diesel = cheapest.getByText(/^Unioil · Balulang · /);
	await expect(diesel).toBeVisible();
	await expect(diesel).not.toContainText('est.');
	await expect(cheapest).toContainText('₱55.35');
	await expect(cheapest).toContainText('Euro 5 Diesel');

	const kerosene = cheapest.getByText(/^Seaoil · Consolacion · /);
	await expect(kerosene).toBeVisible();
	await expect(kerosene).not.toContainText('est.');
	await expect(cheapest).toContainText('₱70.60');
});

test('(10) without JavaScript the ranking is in the HTML and Next still works', async ({
	page
}) => {
	loadFixtures('empty', 'dashboard');
	// Only scripts: the built CSS is also served from /_app/
	await page.route('**/_app/**', (route) =>
		route.request().resourceType() === 'script' ? route.abort() : route.continue()
	);
	await page.goto('/');

	const rows = page.getByRole('list', { name: 'Station ranking' }).getByRole('listitem');
	await expect(rows).toHaveCount(5);

	await page.getByRole('link', { name: 'Next' }).click();

	await expect(page).toHaveURL(/page=2/);
	await expect(page.getByText('Page 2 of 3')).toBeVisible();
	// Rank 6 is Petron Lapasan at 62.45
	await expect(rows.first()).toContainText('₱62.45');
});

test('(11) every ranking bar is hidden from screen readers', async ({ page }) => {
	loadFixtures('empty', 'dashboard');
	await page.goto('/');

	const bars = page.locator('.bar');
	await expect(bars).toHaveCount(5);
	for (const bar of await bars.all()) {
		await expect(bar).toHaveAttribute('aria-hidden', 'true');
	}
});
