<script lang="ts">
	import { page } from '$app/state';
	import { resolve } from '$app/paths';
	import { afterNavigate } from '$app/navigation';

	let menu: HTMLElement | undefined = $state();

	// Choosing a tab in the open mobile menu navigates; close the menu once the new page is shown
	afterNavigate(() => menu?.hidePopover());

	const tabs = [
		{ label: 'Dashboard', href: resolve('/') },
		{ label: 'Analytics', href: resolve('/analytics') },
		{ label: 'Contribute', href: resolve('/contribute') }
	];

	function toggleMode() {
		const root = document.documentElement;
		const current =
			root.dataset.theme ?? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
		const next = current === 'dark' ? 'light' : 'dark';
		root.dataset.theme = next;

		try {
			localStorage.setItem('theme', next);
		} catch {
			// The page still switches but the choice is not saved
		}
	}
</script>

<header>
	<a class="logo" href={resolve('/')}>
		<span class="logo-mark" aria-hidden="true"></span>
		CDO Fuel Price Tracker
	</a>

	{#snippet tabLinks()}
		{#each tabs as tab (tab.href)}
			<a href={tab.href} aria-current={page.url.pathname === tab.href ? 'page' : undefined}>
				{tab.label}
			</a>
		{/each}
	{/snippet}

	<nav class="tabs" aria-label="Main">
		{@render tabLinks()}
	</nav>

	<button type="button" class="mode" onclick={toggleMode}>
		<span class="to-light">
			<span aria-hidden="true">☀</span><span class="visually-hidden">Switch to light mode</span>
		</span>
		<span class="to-dark">
			<span aria-hidden="true">☾</span><span class="visually-hidden">Switch to dark mode</span>
		</span>
	</button>

	<!-- The native popover gives Escape, click-outside closing and focus return for free -->
	<button type="button" class="menu-button" popovertarget="site-menu" aria-label="Menu">
		<span class="burger" aria-hidden="true">☰</span>
		<span class="close" aria-hidden="true">✕</span>
	</button>

	<nav id="site-menu" class="menu" popover aria-label="Main" bind:this={menu}>
		{@render tabLinks()}
	</nav>
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
		font:
			700 1.0625rem 'Montserrat',
			sans-serif;
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

	/* A class, not `nav`: display: flex on the popover would override the browser's hidden state */
	.tabs {
		display: flex;
		gap: 6px;
		height: 100%;
	}

	nav a {
		padding: 0 18px;
		height: 100%;
		align-content: center;
		font:
			500 0.875rem 'Inter',
			sans-serif;
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

	.mode {
		margin-left: auto;
	}

	.mode,
	.menu-button {
		flex: none;
		width: 38px;
		height: 38px;
		box-sizing: border-box;
		display: grid;
		place-items: center;
		padding: 0;
		border: 1px solid var(--line);
		border-radius: 10px;
		background: none;
		color: var(--ink);
		font-size: 17px;
		cursor: pointer;
		transition: background 0.2s;
	}

	.mode:hover,
	.menu-button:hover {
		background: var(--soft);
	}

	.menu-button {
		display: none;
		font-size: 18px;
	}

	.close,
	header:has(.menu:popover-open) .burger {
		display: none;
	}

	header:has(.menu:popover-open) .close {
		display: inline;
	}

	@media (max-width: 767px) {
		header {
			gap: 10px;
			height: 60px;
			padding: 0 16px;
		}

		/* Lets the name wrap instead of pushing the buttons off screen */
		.logo {
			min-width: 0;
		}

		.tabs {
			display: none;
		}

		.menu-button {
			display: grid;
		}

		.menu:popover-open {
			display: flex;
			flex-direction: column;
		}

		.menu {
			inset: 60px 0 auto 0;
			width: auto;
			margin: 0;
			padding: 8px;
			border: 0;
			border-bottom: 1px solid var(--line);
			background: var(--card);
			color: var(--ink);
			box-shadow: var(--raised);
		}

		.menu a {
			height: auto;
			padding: 14px 12px;
			border-radius: 10px;
			font-size: 15px;
		}

		.menu a[aria-current='page'] {
			background-color: var(--soft);
		}
	}
</style>
