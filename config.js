/* Layover — backend configuration.

   Leave these empty and the site runs fully on seeded local data: the board,
   gates and Reroute all work, nothing breaks, nothing is stored anywhere but
   the visitor's own browser.

   Fill them in and the same site becomes multi-user: real accounts, real
   timetables, real groups, real friends, updating live across devices.

   Both values are safe to commit. The anon key is a public client key; every
   table is protected by row level security policies in schema.sql, so what a
   visitor can read or write is decided by the database, not by this file.

   Where to find them:
     Supabase dashboard → your project → Settings → API
       url     = Project URL
       anonKey = Project API keys → anon / public
*/
window.LAYOVER_CONFIG = {
  url: "",
  anonKey: ""
};
