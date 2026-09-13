# Turning on accounts, friends and shared groups

Layover works with no backend at all — the board, gates, My Day and Reroute all run
on seeded data in the visitor's own browser. Everything below is what turns that
into a real multi-user platform. It takes about five minutes and costs nothing.

You only need to do this once. Nothing here is secret.

---

## 1. Create the project

1. Go to **supabase.com** → sign in with GitHub → **New project**.
2. Name it `layover`, pick any region (Frankfurt or Singapore are closest to the UAE),
   and set a database password. Free tier is fine.
3. Wait for it to finish provisioning (~2 minutes).

## 2. Create the tables

1. In the project, open **SQL Editor** → **New query**.
2. Paste the entire contents of [`schema.sql`](schema.sql) and press **Run**.

That creates the five tables, the row-level-security policies, the trigger that gives
every new signup a profile, and the twelve seeded example students with their
timetables and gates — so the board is populated for a visitor who never signs in.

The file is safe to re-run; it drops and recreates its own objects.

## 3. Let people sign in without waiting for email

By default Supabase makes new users confirm their address before they can sign in.
For a competition where judges will create a throwaway account in ten seconds, turn
that off:

**Authentication → Sign In / Providers → Email** → switch **Confirm email** off → Save.

Leave it on if you would rather have verified addresses; the app handles both and
will tell the user to go and check their inbox.

## 4. Point the site at it

**Settings → API**, then copy two values into [`config.js`](config.js):

```js
window.LAYOVER_CONFIG = {
  url:     "https://xxxxxxxxxxxx.supabase.co",   // Project URL
  anonKey: "eyJhbGciOi..."                       // Project API keys → anon / public
};
```

Commit and push. GitHub Pages redeploys in under a minute and the site is live
multi-user.

### Why it is fine to commit these

The anon key is a **public client key** — it is designed to ship in browser code.
It grants nothing on its own. What any given visitor can read or write is decided
entirely by the row-level-security policies in `schema.sql`, enforced by Postgres:

- you can only edit **your own** profile and timetable
- you only appear on the board if **you** tick "Show me on the board"
- you can only join or leave a gate **as yourself**
- only a gate's **host** can change or close it
- a friendship row is visible only to the **two people in it**, and only the
  person who received a request can accept it

Never commit the `service_role` key. That one does bypass every policy.

---

## If something goes wrong

The site never depends on any of this. If the project is paused, the key is wrong,
or the network is down, Layover falls back to local seeded data and the People page
says so plainly instead of showing an error. Nothing else on the site changes.

To check what state it is in, open the browser console and type `Cloud.status` —
it will be one of `off`, `connecting`, `ready` or `error` (with `Cloud.error`
holding the reason).
