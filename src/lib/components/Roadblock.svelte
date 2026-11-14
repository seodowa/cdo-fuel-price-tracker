<script lang="ts">
	let { status }: { status: number } = $props();
</script>

<!-- Roadblock with the status code on a diamond sign. The code appears nowhere else,
     so the drawing is an image with a text alternative, not decoration -->
<svg viewBox="0 0 200 172" role="img" aria-label="Error {status}">
	<defs>
		<pattern
			id="stripes"
			width="20"
			height="20"
			patternUnits="userSpaceOnUse"
			patternTransform="rotate(45)"
		>
			<rect width="10" height="20" fill="#f2f2f2" />
			<rect x="10" width="10" height="20" fill="#e8590c" />
		</pattern>
	</defs>

	<rect class="metal" x="97" y="100" width="6" height="26" />
	<rect class="metal" x="34" y="144" width="7" height="26" rx="1" />
	<rect class="metal" x="159" y="144" width="7" height="26" rx="1" />
	<rect
		x="18"
		y="122"
		width="164"
		height="24"
		rx="3"
		fill="url(#stripes)"
		stroke="#1a1a1a"
		stroke-width="2"
	/>

	<polygon
		points="100,4 152,56 100,108 48,56"
		fill="#f5c518"
		stroke="#1a1a1a"
		stroke-width="3"
		stroke-linejoin="round"
	/>
	<polygon
		points="100,13 143,56 100,99 57,56"
		fill="none"
		stroke="#1a1a1a"
		stroke-width="2.5"
		stroke-linejoin="round"
	/>
	<text x="100" y="65" text-anchor="middle">{status}</text>
</svg>

<style>
	svg {
		width: 180px;
		height: auto;
		margin-bottom: 12px;
	}

	/* Posts and legs follow the theme; the sign and stripes keep road colours in both modes */
	.metal {
		fill: var(--muted);
	}

	text {
		font:
			700 26px 'Montserrat',
			sans-serif;
		fill: #1a1a1a;
	}
</style>
