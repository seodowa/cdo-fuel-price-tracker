# Decisions

Newest first. Each entry is the date, the decision made and the reason for it.

## 2026-10-26
- The app is a web app built with SvelteKit and Supabase.
  Reason: a web app reaches users without an app install, and Supabase provides the database, sign-in and access rules without a custom backend.
- Fuel prices are crowdsourced. Anyone can view prices, and only signed-in users can submit them.
  Reason: requiring sign-in to submit allows limits and bans per account, which keeps spam out of the data.
- Each station's baseline price is collected once. Weekly price adjustments are then applied on top of it.
  Reason: stations change prices together each week, so one adjustment updates every station without re-collecting prices.
- Users can update a single branch's price when that branch changes its price on its own.
  Reason: some branches set prices outside the weekly adjustment, and the tracker would show a wrong price without an update.
- Weekly price adjustments are fetched automatically from external sources. The method is not chosen yet. Options are a scraper, an LLM reading Facebook images, or Google AI Overview through SerpAPI.
  Reason: adjustments are announced publicly each week, so fetching them removes manual entry.
- Weekly price adjustments are fetched and applied automatically as far as possible.
  Reason: the goal is a tracker that stays current without manual work each week.
- A correction to a wrong price record updates that record instead of adding a new one.
  Reason: keeps one record per price change, so the history is not cluttered with superseded entries.
- Price logic, validation and database access rules are tested first. Key user flows get smoke tests.
  Reason: a wrong price is the app's main failure and goes unnoticed without tests.
- All Stratum agents run on Opus at medium effort.
  Reason: chosen to use one model and effort level for every agent.
