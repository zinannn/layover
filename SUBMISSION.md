# TWE post — copy/paste into twe.co → Create New

**Title:** Layover — the campus that only exists between your last class and your bus

---

**1. The Problem**

RIT Dubai is a commuter campus in Dubai Silicon Oasis, and its commuter buses run on a schedule almost nobody designs around: **one arrival in the morning, and two departures in the afternoon — 3:00 p.m. and 6:00 p.m.** — all from Parking Lot 3.

So a student whose last class ends at 3:10 p.m. does not leave at 3:10. They leave at 6:00. A student whose first class is at 11:00 a.m. arrived on the single morning bus hours earlier. The timetable hands them hours they never chose, at both ends of the day, every week, for four years.

That time isn't rest and it isn't study. It's the worst kind of time — too long to waste, too short to go home, and almost always spent alone, because no student can see which of the other 900 people on campus happens to be stranded in the same window.

**2. My Solution**

**Layover** treats the bus timetable as the social graph.

Every other campus platform matches students on interests. On a commuter campus, interest isn't the binding constraint — **co-presence** is. Two students who'd get on brilliantly never meet because their free hours don't intersect and they leave on different buses.

Layover computes the window in which a meeting is physically possible, and builds on top of it:

- **The Departure Board** — a live terminal board of everyone currently grounded, showing how long they're free, where they are, which bus they're on, and the exact **overlap in minutes** with your window. Under twenty minutes, it says so instead of pretending it's a match.
- **Gates** — plans sized to a layover rather than events you have to leave early: a study block for a course you share, a co-op mock interview, a gym slot, and a **Quiet Gate** for students who want company without conversation. Each one is checked against your window *and* your bus before you can join.
- **My Day** — your true campus day, separating the three kinds of dead time: the morning wait, the gaps between classes, and the tail before departure.
- **Reroute** — the part that prevents the problem instead of decorating it. Before registration, test a section swap and see what it does to the shape of your week: how many days you must be on campus, and how many dead hours the bus schedule adds on top.
- **Ways home** — the RIT bus is not the only option. Layover shows the RTA routes from the Silicon Oasis HQ stops, so being stranded until 18:00 is a choice rather than a sentence.

**It is a real platform, not a mockup.** Create an account and your timetable follows you across devices; open a group and other students can genuinely join it; add friends and filter the board to just them. It updates live — open it on two devices and a group opened on one appears on the other without a refresh.

You appear on the board only if you tick "Show me on the board". Every table is protected by row-level security in the database: you can only edit your own profile and timetable, only join a group as yourself, only close a group you host, and a friendship is visible only to the two people in it.

**3. Project Link**

https://zinannn.github.io/layover/

**4.** #designathon2026
