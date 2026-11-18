<script lang="ts">
	import { resolve } from '$app/paths';
	import { ageLabel, barPercent, formatCents } from '#lib/dashboard-functions.ts';
	import type { Page } from '#lib/models/dashboard.ts';

	type Props = {
		page: Page;
		fuel: string;
		today: string;
		highest: number;
		average: number;
	};

	let { page, fuel, today, highest, average }: Props = $props();

	// The page number lives in the URL, so these are plain links that also work without JavaScript
	const href = (n: number) => resolve(`/?fuel=${fuel}&page=${n}`);
</script>

<ol class="rows" aria-label="Station ranking">
	{#each page.rows as row (row.stationId)}
		<li class="row">
			<span class="rank">{row.rank}</span>
			<div class="station">
				<div class="brand">{row.brand}</div>
				<div class="meta">
					{row.street}, {row.barangay} · {ageLabel(row.reportedAt, today)}{row.isEstimate
						? ' · est.'
						: ''}
				</div>
			</div>
			<div class="bar" aria-hidden="true">
				<div
					class="fill"
					class:first={row.rank === 1}
					style:width="{barPercent(row.cents, highest)}%"
				></div>
			</div>
			<div class="price">
				₱{formatCents(row.cents)}
				<span class="product">{row.product}</span>
			</div>
		</li>
	{/each}
</ol>

<p class="legend">est. = reported price plus weekly adjustments since then</p>

<div class="footer">
	<span class="average">City avg ₱{formatCents(average)} · bars scaled to highest price</span>

	<nav class="pagination" aria-label="Ranking pages">
		{#if page.pageNumber > 1}
			<a class="step" href={href(page.pageNumber - 1)} data-sveltekit-reset="false"
				><span aria-hidden="true">‹</span> Prev</a
			>
		{:else}
			<span class="step off"><span aria-hidden="true">‹</span> Prev</span>
		{/if}

		<span class="count">Page {page.pageNumber} of {page.pages}</span>

		{#if page.pageNumber < page.pages}
			<a class="step" href={href(page.pageNumber + 1)} data-sveltekit-reset="false"
				>Next <span aria-hidden="true">›</span></a
			>
		{:else}
			<span class="step off">Next <span aria-hidden="true">›</span></span>
		{/if}
	</nav>
</div>

<style>
	.rows {
		margin: 0;
		padding: 0;
		list-style: none;
	}

	/* Phones: rank, station and price on one line, the bar on its own line under the station and
	   price, as in the mobile design */
	.row {
		display: grid;
		grid-template-columns: 22px minmax(0, 1fr) auto;
		gap: 8px 12px;
		align-items: center;
		padding: 12px 0;
		border-top: 1px solid var(--line);
	}

	.rank {
		font:
			500 12px 'Roboto',
			sans-serif;
		color: var(--muted);
	}

	/* Long brand, street or product names wrap instead of widening the row */
	.station,
	.price {
		min-width: 0;
		overflow-wrap: anywhere;
	}

	.brand {
		font-size: 14px;
		font-weight: 600;
	}

	.meta,
	.product {
		font-size: 12px;
		color: var(--muted);
	}

	.bar {
		grid-row: 2;
		grid-column: 2 / 4;
		height: 8px;
		border-radius: 4px;
		background: var(--soft);
	}

	.fill {
		height: 100%;
		border-radius: 4px;
		background: var(--mid);
	}

	.fill.first {
		background: var(--accent);
	}

	/* The bar comes before the price in the markup, so pin the price to the first line */
	.price {
		grid-row: 1;
		grid-column: 3;
		font:
			500 17px 'Roboto',
			sans-serif;
		text-align: right;
		font-variant-numeric: tabular-nums;
	}

	.product {
		display: block;
		font-family: 'Inter', sans-serif;
		font-weight: 400;
	}

	/* margin-top: auto pushes the legend and footer to the bottom of the card when the list is short */
	.legend {
		margin: auto 0 0;
		padding-top: 12px;
		font-size: 12px;
		color: var(--muted);
	}

	.footer {
		display: flex;
		flex-wrap: wrap;
		gap: 10px;
		align-items: center;
		justify-content: center;
		margin-top: 12px;
		padding-top: 12px;
		border-top: 1px solid var(--line);
	}

	.average {
		font:
			12px 'Roboto',
			sans-serif;
		color: var(--muted);
	}

	.pagination {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.step {
		padding: 6px 10px;
		border-radius: 6px;
		font-size: 12.5px;
		font-weight: 600;
		color: var(--ink);
		text-decoration: none;
	}

	/* No page to go to: shown faded, and as text so it can't be clicked or focused */
	.off {
		opacity: 0.35;
	}

	.count {
		font:
			500 12px 'Roboto',
			sans-serif;
		color: var(--muted);
	}

	/* Desktop, the Dashboard's 768px breakpoint: one line per station with the bar in its own
	   column, as in the desktop design */
	@media (min-width: 768px) {
		.row {
			grid-template-columns: 24px minmax(110px, 170px) minmax(60px, 1fr) 76px;
			gap: 14px;
		}

		.price,
		.bar {
			grid-row: auto;
			grid-column: auto;
		}

		.bar {
			height: 10px;
			border-radius: 5px;
		}

		.fill {
			border-radius: 5px;
		}
	}
</style>
