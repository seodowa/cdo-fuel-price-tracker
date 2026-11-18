<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { averageCents, paginate, pickFuel, rankStations } from '#lib/dashboard-functions.ts';
	import Pagination from '#lib/components/Pagination.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const fuel = $derived(pickFuel(page.url.searchParams.get('fuel'), data.categories));
	const pageParam = $derived(page.url.searchParams.get('page'));
	const ranked = $derived(rankStations(data.rows, fuel));
	const current = $derived(paginate(ranked, pageParam));
	const today = $derived(data.today);
	// Across every page, not just the one shown; null when nothing is ranked
	const average = $derived(averageCents(ranked));

	// Bars scale to the highest price on every page, which is the last ranked row
	const highest = $derived(ranked.at(-1)?.cents ?? 0);
</script>

<svelte:head>
	<title>Dashboard · CDO Fuel Price Tracker</title>
</svelte:head>

<main class="container">
	<h1 class="visually-hidden">Fuel prices in Cagayan de Oro</h1>

	<div class="dashboard">
		<!-- Left column on desktop; stacks above the ranking on mobile -->
		<div class="side">
			<section class="card adjustment" aria-labelledby="adjustment-title">
				<h2 id="adjustment-title" class="label">Price adjustment</h2>
				<!-- T035: "As of …", "Change per litre vs. previous week", one row per fuel -->
			</section>

			<section class="card cheapest" aria-labelledby="cheapest-title">
				<h2 id="cheapest-title" class="label">Cheapest in CDO</h2>
				<!-- T025: one row per fuel, or "No prices reported yet" -->
			</section>
		</div>

		<section class="card ranking" aria-labelledby="ranking-title">
			<div class="ranking-head">
				<h2 id="ranking-title" class="title">Station ranking</h2>
				<div class="fuels">
					{#each data.categories as c (c)}
						<a
							class="chip"
							href={resolve(`/?fuel=${c}`)}
							data-sveltekit-noscroll
							aria-current={c === fuel ? 'true' : undefined}>{c}</a
						>
					{/each}
				</div>
			</div>

			{#if average === null}
				<p class="empty">No prices reported yet</p>
			{:else}
				<Pagination page={current} {fuel} {today} {highest} {average} />
			{/if}
		</section>
	</div>
</main>

<style>
	.container {
		max-width: 1280px;
		margin: 0 auto;
		padding: 20px 16px 36px;
	}

	/* Two equal columns when both fit at 420px, otherwise one column in source order */
	.dashboard {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(min(100%, 420px), 1fr));
		gap: 16px;
	}

	.side {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.card {
		background: var(--card);
		box-shadow: var(--shadow);
		border-radius: 14px;
	}

	.adjustment {
		padding: 24px 26px;
	}

	.cheapest {
		padding: 18px 24px;
	}

	.ranking {
		display: flex;
		flex-direction: column;
		padding: 20px 16px;
	}

	/* "PRICE ADJUSTMENT", "CHEAPEST IN CDO": the text stays sentence case for screen readers */
	.label {
		margin: 0;
		font:
			600 11px 'Montserrat',
			sans-serif;
		letter-spacing: 0.12em;
		text-transform: uppercase;
		color: var(--muted);
	}

	.cheapest .label {
		margin-bottom: 8px;
	}

	.ranking-head {
		display: flex;
		flex-wrap: wrap;
		gap: 10px;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 14px;
	}

	.title {
		margin: 0;
		font:
			600 20px 'Montserrat',
			sans-serif;
		white-space: nowrap;
	}

	.empty {
		margin: 0;
		padding: 12px 0;
		border-top: 1px solid var(--line);
		font-size: 14px;
		color: var(--muted);
	}

	.fuels {
		display: flex;
		gap: 6px;
	}

	.chip {
		padding: 7px 14px;
		border: 1px solid var(--line);
		border-radius: 6px;
		font-size: 12.5px;
		font-weight: 500;
		color: var(--muted);
		text-decoration: none;
		text-transform: capitalize;
	}

	.chip[aria-current='true'] {
		background: var(--accent);
		border-color: var(--accent);
		color: var(--on-accent);
	}

	/* Desktop, the Dashboard's 768px breakpoint: the roomier spacing of the desktop design */
	@media (min-width: 768px) {
		.container {
			padding: 32px 40px 48px;
		}

		.dashboard,
		.side {
			gap: 20px;
		}

		.ranking {
			padding: 24px 28px;
		}
	}
</style>
