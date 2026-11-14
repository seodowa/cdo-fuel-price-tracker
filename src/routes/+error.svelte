<script lang="ts">
	import { page } from '$app/state';
	import { resolve } from '$app/paths';
	import Roadblock from '#lib/components/Roadblock.svelte';
</script>

<svelte:head>
	<title>Error · CDO Fuel Price Tracker</title>
</svelte:head>

<main>
	<Roadblock status={page.status} />

	{#if page.status === 404}
		<!-- Reloading a wrong link fails again, so point to the Dashboard instead -->
		<h1>Page not found</h1>
		<p>Check the link, or go to the <a href={resolve('/')}>Dashboard</a>.</p>
	{:else}
		<h1>{page.error?.message}</h1>
		<!-- "Try again" reloads the page that failed, query included (keeps ?fuel= and ?page=).
		     Not resolve(): it only accepts known routes, and page.url already holds the base path -->
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -->
		<p><a href={page.url.href}>Try again</a></p>
	{/if}
</main>

<style>
	main {
		display: grid;
		justify-items: center;
		gap: 12px;
		padding: 64px 16px;
		text-align: center;
	}

	h1 {
		margin: 0;
		font:
			700 1.5rem 'Montserrat',
			sans-serif;
	}

	p {
		margin: 0;
		color: var(--muted);
	}

	/* app.css removes the underline from all links; a link inside text needs it back */
	a {
		text-decoration: underline;
	}

	a:hover {
		color: var(--ink);
	}
</style>
