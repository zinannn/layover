/* Layover — backend configuration.

   Leave these empty and the site runs fully on seeded local data: the board,
   gates and Reroute all work, nothing breaks, nothing is stored anywhere but
   the visitor's own browser.

   Filled in, the same site becomes multi-user: real accounts, real timetables,
   real groups, real friends, updating live across devices.

   Both values are safe to commit. This is a publishable client key; it grants
   nothing on its own. What any visitor can read or write is decided by the
   row level security policies in schema.sql, enforced by Postgres.

   Never put the secret / service_role key here — that one bypasses every policy.

   Supabase dashboard → Settings → API Keys
*/
window.LAYOVER_CONFIG = {
  url:     "https://fcuhxzkfpjgtyjwcziwv.supabase.co",
  anonKey: "sb_publishable_5dAfnDEEVcZqt7l3-jMOiA_LEt0wHcW"
};
