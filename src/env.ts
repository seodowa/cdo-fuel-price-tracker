import { defineEnvVars } from '@sveltejs/kit/env';

// A missing or empty value stops the app at start-up, not at the first page load
function required(name: string) {
	return (value: string | undefined): string => {
		if (!value) throw new Error(`${name} is not set. Copy .env.example to .env and fill it in`);
		return value;
	};
}

// Both are private: only the server reads Supabase in this app. SUPABASE_DB_URL is left out on
// purpose, because only the e2e helper uses it.
export const variables = defineEnvVars({
	SUPABASE_URL: {
		description: 'Supabase API URL, e.g. http://127.0.0.1:54321 locally',
		schema: required('SUPABASE_URL')
	},
	SUPABASE_PUBLISHABLE_KEY: {
		description: 'Supabase publishable key (sb_publishable_…), read-only through RLS',
		schema: required('SUPABASE_PUBLISHABLE_KEY')
	}
});
