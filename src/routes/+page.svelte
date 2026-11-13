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
				<!-- T023: fuel links (chips) -->
			</div>
			<!-- T023: <ol aria-label="Station ranking">; T024: legend, city avg, pagination -->
		</section>
	</div>
</main>

<style>
	.container {
		max-width: 1280px;
		margin: 0 auto;
		padding: 32px 40px 48px;
	}

	/* Two equal columns when both fit at 420px, otherwise one column in source order */
	.dashboard {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(min(100%, 420px), 1fr));
		gap: 20px;
	}

	.side {
		display: flex;
		flex-direction: column;
		gap: 20px;
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
		padding: 24px 28px;
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

	/* T046 */
	@media (max-width: 767px) {
		.container {
			padding: 20px 16px 36px;
		}

		.dashboard,
		.side {
			gap: 16px;
		}

		.ranking {
			padding: 20px 16px;
		}
	}
</style>
