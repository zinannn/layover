# Layover

**DesignAthon 2026 — GDC RIT Dubai × +TWE**

RIT Dubai's commuter buses have **one morning arrival and two afternoon departures: 15:00 and 18:00**, from Parking Lot 3. A student whose last class ends at 15:10 doesn't leave at 15:10 — they leave at 18:00.

That gap isn't a break. It's a **layover**: too long to waste, too short to go home, and spent alone because nobody can see who else is stranded in the same window.

Layover reads the bus timetable as a social graph.

- **The Departure Board** — everyone currently grounded, with the exact overlap in minutes with your own window.
- **Gates** — plans sized to a layover, checked against your window *and* your bus before you can join.
- **My Day** — your true campus day: morning wait, gaps, and the tail before departure.
- **Reroute** — test a section swap before registration and see what it does to the shape of your week: campus days and dead hours.

Explore with no account — the board, gates and Reroute come with a built-in week. Sign in to sync your timetable across devices and appear on the board for other students.

`#designathon2026`

---

## Accounts, friends and shared groups

The site ships connected to a Supabase backend: real accounts, real timetables,
real gates, real friends, updating live across devices. Point it at your own
free Supabase project to run your own copy.

See [SETUP.md](SETUP.md). About five minutes, no cost, nothing secret committed.
