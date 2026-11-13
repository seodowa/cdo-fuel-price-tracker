// Rows exactly as the selects in specs/002-public-dashboard/contracts/dashboard.md return them.
// PostgREST sends bigint ids and numeric amounts as JSON numbers, and dates as 'YYYY-MM-DD'.

export type CurrentPriceRow = {
	station_id: number;
	product_id: number;
	price: number; // ₱, 2 decimals
	reported_at: string;
	is_estimate: boolean;
};

export type StationRow = {
	id: number;
	street_address: string;
	// Embedded many-to-one relations arrive as objects, not arrays
	brand: { name: string };
	barangay: { name: string };
};

export type ProductRow = {
	id: number;
	name: string;
	category_id: number;
};

export type CategoryRow = {
	id: number;
	name: string;
};

export type ShiftRow = {
	brand_id: number;
	amount: number; // ₱ per litre, -20 to 20
	effective_on: string;
};
