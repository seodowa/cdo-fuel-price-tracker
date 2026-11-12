<script lang="ts">
	import { page } from '$app/state';
	import { resolve } from '$app/paths';

	const tabs = [
		{ label: 'Dashboard', href: resolve('/') },
		{ label: 'Analytics', href: resolve('/analytics') },
		{ label: 'Contribute', href: resolve('/contribute') }
	];
</script>

<header>
	<a class="logo" href={resolve('/')}>
		<span class="logo-mark" aria-hidden="true"></span>
		CDO Fuel Price Tracker
	</a>

	<nav aria-label="Main">
		{#each tabs as tab (tab.href)}
			<a href={tab.href} aria-current={page.url.pathname === tab.href ? 'page' : undefined}>
				{tab.label}
			</a>
		{/each}
	</nav>

	<!-- TODO: theme toggle button -->
	<!-- TODO: mobile menu button -->
</header>

<style>
	header {
		display: flex;
		align-items: center;
		gap: 2rem;
		height: 4.5rem;
		padding: 0 2.5rem;
        border-bottom: 1px solid var(--line);
	}

	.logo {
		display: flex;
		align-items: center;
		gap: 0.625rem;
		font: 700 1.0625rem 'Montserrat', sans-serif;
		letter-spacing: 0.02em;
	}

	/* Outlined square with a filled center: the mock's logo mark */
	.logo-mark {
		display: grid;
		place-items: center;
		width: 1.375rem;
		height: 1.375rem;
		box-sizing: border-box;
		border: 2px solid var(--accent);
		border-radius: 4px;
	}

	.logo-mark::after {
		content: '';
		width: 0.5rem;
		height: 0.5rem;
		background: var(--accent);
	}

	nav {
		display: flex;
		gap: 6px;
		height: 100%;
	}

	nav a {
		padding: 0 18px;
		height: 100%;
		align-content: center;
		font: 500 0.875rem 'Inter', sans-serif;
		color: var(--muted);

		/* Hidden underline that gets animated/displayed when hovered/active */
		background-image: linear-gradient(var(--accent), var(--accent));
		background-repeat: no-repeat;
		background-position: left bottom;
		background-size: 0% 2px;
		transition:
			background-size 0.28s ease,
			color 0.2s;
	}

	nav a:hover,
	nav a[aria-current='page'] {
		background-size: 100% 2px;
		color: var(--ink);
	}
</style>
