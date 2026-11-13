import { expect, test, type Browser, type Page } from '@playwright/test';

const desktop = { width: 1280, height: 800 };
const mobile = { width: 390, height: 844 };

// Aborting the app's scripts means no Svelte code runs: only server HTML, app.css and the inline
// script. Only scripts, because the built app.css is also served from /_app/
async function blockAppJs(page: Page) {
	await page.route('**/_app/**', (route) =>
		route.request().resourceType() === 'script' ? route.abort() : route.continue()
	);
}

async function bodyBackground(page: Page) {
	return page.locator('body').evaluate((body) => getComputedStyle(body).backgroundColor);
}

// Body colour on a fresh page with no saved choice and no JS: the device's own colour
async function deviceBackground(browser: Browser, colorScheme: 'light' | 'dark') {
	const page = await browser.newPage({ colorScheme });
	await blockAppJs(page);
	await page.goto('/');
	const background = await bodyBackground(page);
	await page.close();
	return background;
}

// Clicks before hydration do nothing, so wait until the app bundle has loaded
async function gotoHydrated(page: Page, path: string) {
	await page.goto(path, { waitUntil: 'networkidle' });
}

test.describe('desktop', () => {
	test.use({ viewport: desktop });

	test('(1) banner shows the name and three tabs, no sign-in controls', async ({ page }) => {
		await page.goto('/');
		const banner = page.getByRole('banner');

		await expect(banner).toContainText('CDO Fuel Price Tracker');
		for (const name of ['Dashboard', 'Analytics', 'Contribute']) {
			await expect(banner.getByRole('link', { name, exact: true })).toBeVisible();
		}
		await expect(banner).not.toContainText('Log in');
		await expect(banner).not.toContainText('Sign up');
	});

	test('(2) banner has a mode toggle', async ({ page }) => {
		await page.goto('/');
		await expect(
			page.getByRole('banner').getByRole('button', { name: /^Switch to (light|dark) mode$/ })
		).toBeVisible();
	});

	for (const name of ['Analytics', 'Contribute']) {
		test(`(3) ${name} shows Coming soon and its tab is current`, async ({ page }) => {
			await page.goto(`/${name.toLowerCase()}`);

			await expect(page.getByText('Coming soon')).toBeVisible();
			await expect(
				page.getByRole('banner').getByRole('link', { name, exact: true })
			).toHaveAttribute('aria-current', 'page');
		});
	}

	test('(10) Tab reaches logo, tabs and toggle in order; toggle name changes', async ({ page }) => {
		await page.emulateMedia({ colorScheme: 'dark' });
		await gotoHydrated(page, '/');
		const banner = page.getByRole('banner');
		const order = [
			banner.getByRole('link', { name: 'CDO Fuel Price Tracker' }),
			banner.getByRole('link', { name: 'Dashboard', exact: true }),
			banner.getByRole('link', { name: 'Analytics', exact: true }),
			banner.getByRole('link', { name: 'Contribute', exact: true }),
			banner.getByRole('button', { name: 'Switch to light mode' })
		];

		for (const target of order) {
			await page.keyboard.press('Tab');
			await expect(target).toBeFocused();
		}

		await page.keyboard.press('Enter');
		await expect(banner.getByRole('button', { name: 'Switch to dark mode' })).toBeFocused();
	});
});

test.describe('mobile', () => {
	test.use({ viewport: mobile });

	test('(4) Menu button opens the tabs, Escape closes, choosing a tab navigates', async ({
		page
	}) => {
		await gotoHydrated(page, '/');
		const banner = page.getByRole('banner');
		const menuButton = banner.getByRole('button', { name: 'Menu' });
		const analytics = banner.getByRole('link', { name: 'Analytics', exact: true });

		// The inline tabs are hidden and the menu is closed, so no tab link is visible
		await expect(analytics).toBeHidden();

		await menuButton.click();
		for (const name of ['Dashboard', 'Analytics', 'Contribute']) {
			await expect(banner.getByRole('link', { name, exact: true })).toBeVisible();
		}

		await page.keyboard.press('Escape');
		await expect(analytics).toBeHidden();

		await menuButton.click();
		await analytics.click();
		await expect(page).toHaveURL('/analytics');
		await expect(analytics).toBeHidden();
	});

	test('(5) Dashboard cards are stacked on one left edge', async ({ page }) => {
		await page.goto('/');
		const cards = page.locator('section');
		await expect(cards).not.toHaveCount(0);

		const lefts = new Set<number>();
		for (const card of await cards.all()) {
			const box = await card.boundingBox();
			if (box) lefts.add(Math.round(box.x));
		}
		expect(lefts.size).toBe(1);
	});
});

test.describe('mode', () => {
	test('(6) without JS the page follows the device', async ({ browser }) => {
		const light = await deviceBackground(browser, 'light');
		const dark = await deviceBackground(browser, 'dark');

		expect(light).not.toBe(dark);
	});

	test('(7) a toggled choice survives a reload', async ({ page, browser }) => {
		const light = await deviceBackground(browser, 'light');

		await page.emulateMedia({ colorScheme: 'dark' });
		await gotoHydrated(page, '/');
		await page.getByRole('button', { name: 'Switch to light mode' }).click();

		// Reload with no JS so only the inline script can restore the choice
		await blockAppJs(page);
		await page.reload();

		await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
		expect(await bodyBackground(page)).toBe(light);
	});

	for (const colorScheme of ['light', 'dark'] as const) {
		test(`(8) an invalid saved value is ignored on a ${colorScheme} device`, async ({
			page,
			browser
		}) => {
			const expected = await deviceBackground(browser, colorScheme);

			await page.addInitScript(() => localStorage.setItem('theme', 'blue'));
			await page.emulateMedia({ colorScheme });
			await blockAppJs(page);
			await page.goto('/');

			await expect(page.locator('html')).not.toHaveAttribute('data-theme');
			expect(await bodyBackground(page)).toBe(expected);
		});
	}
});

test('(9) every request during a Dashboard load stays on the app server', async ({ page }) => {
	const origins = new Set<string>();
	page.on('request', (request) => {
		origins.add(new URL(request.url()).origin);
	});

	await page.goto('/', { waitUntil: 'networkidle' });

	expect([...origins]).toEqual(['http://localhost:4173']);
});
