// Shapes the Dashboard works with. Money is integer centavos (research R4).

// One per current_price row, joined with its station, product and category
export type PriceRow = {
	stationId: number;
	brand: string;
	street: string;
	barangay: string;
	product: string;
	category: string;
	cents: number;
	reportedAt: string;
	isEstimate: boolean;
};

export type RankedRow = PriceRow & { rank: number };

export type Page = {
	rows: RankedRow[];
	pageNumber: number;
	pages: number;
};

// A union on kind, so the amounts only exist for an increase or a rollback
export type Adjustment =
	| { kind: 'none' }
	| { kind: 'no-change' | 'mixed'; asOf: string }
	| { kind: 'increase' | 'rollback'; asOf: string; minCents: number; maxCents: number };
