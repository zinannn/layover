/* ============================================================================
   Layover — cloud layer (Supabase)

   Everything here is optional. If config.js has no project in it, or the
   network is unavailable, Cloud stays disabled and the page runs on the local
   seeded data exactly as before. The app never depends on this file working.

   It deliberately produces the same shapes the renderers already consume:
     person = {id, n, m, r, q, place, classes:[{day,start,end,code}]}
     gate   = {id, code, t, title, place, day, a:"HH:MM", b:"HH:MM",
               host, cap, join, tags, d, mine, joined}
   ========================================================================== */
(function () {
  "use strict";

  var CFG = window.LAYOVER_CONFIG || {};
  var SB = window.supabase || window.Supabase;

  var Cloud = window.Cloud = {
    enabled: false,
    status: "off",          // off | connecting | ready | error
    error: null,
    session: null,
    me: null,               // my profile row
    people: [],             // everyone else, board-shaped
    gates: [],              // all gates, card-shaped
    friends: {},            // profileId -> "accepted" | "pending-out" | "pending-in"
    incoming: [],           // friend requests waiting on me
    directory: [],          // every visible profile (for the People page)
    onChange: null          // set by the page
  };

  function m2s(m) {
    var h = Math.floor(m / 60), x = m % 60;
    return (h < 10 ? "0" : "") + h + ":" + (x < 10 ? "0" : "") + x;
  }
  function cap1(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
  function emit() { if (typeof Cloud.onChange === "function") Cloud.onChange(); }

  if (!CFG.url || !CFG.anonKey) { Cloud.status = "off"; return; }
  if (!SB || !SB.createClient) { Cloud.status = "error"; Cloud.error = "Supabase library did not load."; return; }

  var sb = Cloud.client = SB.createClient(CFG.url, CFG.anonKey, {
    auth: { persistSession: true, autoRefreshToken: true }
  });
  Cloud.enabled = true;
  Cloud.status = "connecting";

  /* ------------------------------------------------------------------ read */
  async function loadAll() {
    try {
      var res = await Promise.all([
        sb.from("profiles").select("id,user_id,display_name,major,year,route,place,quiet,visible,is_demo"),
        sb.from("classes").select("profile_id,code,day,start_min,end_min"),
        sb.from("gates").select("id,host_id,title,kind,place,day,start_min,end_min,capacity,note"),
        sb.from("gate_members").select("gate_id,profile_id")
      ]);
      for (var i = 0; i < res.length; i++) if (res[i].error) throw res[i].error;

      var profiles = res[0].data || [], classes = res[1].data || [],
          gates = res[2].data || [], members = res[3].data || [];

      var uid = Cloud.session && Cloud.session.user ? Cloud.session.user.id : null;
      Cloud.me = uid ? (profiles.filter(function (p) { return p.user_id === uid; })[0] || null) : null;
      var myId = Cloud.me ? Cloud.me.id : null;

      var byProfile = {};
      classes.forEach(function (c) {
        (byProfile[c.profile_id] = byProfile[c.profile_id] || [])
          .push({ day: c.day, start: c.start_min, end: c.end_min, code: c.code });
      });

      var name = {};
      profiles.forEach(function (p) { name[p.id] = p.display_name; });

      Cloud.directory = profiles
        .filter(function (p) { return p.id !== myId; })
        .sort(function (a, b) { return a.display_name.localeCompare(b.display_name); });

      Cloud.people = profiles
        .filter(function (p) { return p.id !== myId && p.visible; })
        .map(function (p) {
          return {
            id: p.id, n: p.display_name,
            m: (p.major || "Student") + (p.year ? " · " + p.year : ""),
            r: p.route, q: !!p.quiet, place: p.place,
            classes: byProfile[p.id] || []
          };
        })
        .filter(function (p) { return p.classes.length > 0; });

      var count = {}, joinedByMe = {};
      members.forEach(function (m) {
        count[m.gate_id] = (count[m.gate_id] || 0) + 1;
        if (myId && m.profile_id === myId) joinedByMe[m.gate_id] = true;
      });

      Cloud.gates = gates.map(function (g) {
        var mine = !!(myId && g.host_id === myId);
        return {
          id: g.id, code: mine ? "YOUR GATE" : "GATE", t: g.kind, title: g.title,
          place: g.place, day: g.day, a: m2s(g.start_min), b: m2s(g.end_min),
          host: name[g.host_id] || "A student", cap: g.capacity,
          join: count[g.id] || 0, tags: [cap1(g.kind)], d: g.note || "",
          mine: mine, joined: !!joinedByMe[g.id], cloud: true
        };
      });

      // my own classes, in the local shape
      Cloud.myClasses = myId ? (byProfile[myId] || []) : [];

      await loadFriends(myId);

      Cloud.status = "ready";
      Cloud.error = null;
    } catch (e) {
      var msg = (e && e.message) ? e.message : String(e);
      // connected fine, but schema.sql has not been run against this project yet
      Cloud.needsSchema = (e && e.code === "PGRST205") || /Could not find the table/i.test(msg);
      Cloud.status = "error";
      Cloud.error = msg;
    }
    emit();
  }

  async function loadFriends(myId) {
    Cloud.friends = {}; Cloud.incoming = [];
    if (!myId) return;
    var r = await sb.from("friendships").select("id,requester_id,addressee_id,status");
    if (r.error) return;
    (r.data || []).forEach(function (f) {
      var other = f.requester_id === myId ? f.addressee_id : f.requester_id;
      if (f.status === "accepted") Cloud.friends[other] = "accepted";
      else if (f.requester_id === myId) Cloud.friends[other] = "pending-out";
      else { Cloud.friends[other] = "pending-in"; Cloud.incoming.push({ id: f.id, from: other }); }
    });
  }

  /* ------------------------------------------------------------------ auth */
  Cloud.signUp = async function (email, password, displayName) {
    var r = await sb.auth.signUp({
      email: email, password: password,
      options: { data: { display_name: displayName || "" } }
    });
    if (r.error) return { error: r.error.message };
    if (!r.data.session) return { info: "Check your email to confirm the account, then sign in." };
    return {};
  };
  Cloud.signIn = async function (email, password) {
    var r = await sb.auth.signInWithPassword({ email: email, password: password });
    return r.error ? { error: r.error.message } : {};
  };
  Cloud.signOut = async function () { await sb.auth.signOut(); };

  /* ----------------------------------------------------------------- write */
  function needMe() { return Cloud.me ? Cloud.me.id : null; }

  Cloud.saveProfile = async function (patch) {
    var id = needMe(); if (!id) return { error: "Not signed in." };
    var r = await sb.from("profiles").update(patch).eq("id", id);
    if (r.error) return { error: r.error.message };
    await loadAll(); return {};
  };

  Cloud.addClass = async function (c) {
    var id = needMe(); if (!id) return { error: "Not signed in." };
    var r = await sb.from("classes").insert({
      profile_id: id, code: c.code, day: c.day, start_min: c.start, end_min: c.end
    });
    if (r.error) return { error: r.error.message };
    await loadAll(); return {};
  };
  Cloud.removeClass = async function (c) {
    var id = needMe(); if (!id) return { error: "Not signed in." };
    var r = await sb.from("classes").delete()
      .eq("profile_id", id).eq("code", c.code).eq("day", c.day).eq("start_min", c.start);
    if (r.error) return { error: r.error.message };
    await loadAll(); return {};
  };
  Cloud.replaceClasses = async function (list) {
    var id = needMe(); if (!id) return { error: "Not signed in." };
    var d = await sb.from("classes").delete().eq("profile_id", id);
    if (d.error) return { error: d.error.message };
    if (list.length) {
      var rows = list.map(function (c) {
        return { profile_id: id, code: c.code, day: c.day, start_min: c.start, end_min: c.end };
      });
      var r = await sb.from("classes").insert(rows);
      if (r.error) return { error: r.error.message };
    }
    await loadAll(); return {};
  };

  Cloud.createGate = async function (g) {
    var id = needMe(); if (!id) return { error: "Not signed in." };
    var r = await sb.from("gates").insert({
      host_id: id, title: g.title, kind: g.kind, place: g.place,
      day: g.day, start_min: g.start, end_min: g.end, capacity: g.cap, note: g.note || ""
    }).select("id").single();
    if (r.error) return { error: r.error.message };
    await sb.from("gate_members").insert({ gate_id: r.data.id, profile_id: id });
    await loadAll(); return {};
  };
  Cloud.deleteGate = async function (gateId) {
    var r = await sb.from("gates").delete().eq("id", gateId);
    if (r.error) return { error: r.error.message };
    await loadAll(); return {};
  };
  Cloud.joinGate = async function (gateId) {
    var id = needMe(); if (!id) return { error: "Sign in to join a gate." };
    var r = await sb.from("gate_members").insert({ gate_id: gateId, profile_id: id });
    if (r.error) return { error: r.error.message };
    await loadAll(); return {};
  };
  Cloud.leaveGate = async function (gateId) {
    var id = needMe(); if (!id) return { error: "Not signed in." };
    var r = await sb.from("gate_members").delete().eq("gate_id", gateId).eq("profile_id", id);
    if (r.error) return { error: r.error.message };
    await loadAll(); return {};
  };

  Cloud.addFriend = async function (profileId) {
    var id = needMe(); if (!id) return { error: "Sign in to add people." };
    var r = await sb.from("friendships").insert({ requester_id: id, addressee_id: profileId });
    if (r.error) return { error: r.error.message };
    await loadAll(); return {};
  };
  Cloud.acceptFriend = async function (rowId) {
    var r = await sb.from("friendships").update({ status: "accepted" }).eq("id", rowId);
    if (r.error) return { error: r.error.message };
    await loadAll(); return {};
  };
  Cloud.removeFriend = async function (profileId) {
    var id = needMe(); if (!id) return { error: "Not signed in." };
    var r = await sb.from("friendships").delete()
      .or("and(requester_id.eq." + id + ",addressee_id.eq." + profileId + ")," +
          "and(requester_id.eq." + profileId + ",addressee_id.eq." + id + ")");
    if (r.error) return { error: r.error.message };
    await loadAll(); return {};
  };

  /* -------------------------------------------------------------- realtime */
  var pending = null;
  function nudge() { clearTimeout(pending); pending = setTimeout(loadAll, 350); }

  sb.channel("layover-any")
    .on("postgres_changes", { event: "*", schema: "public" }, nudge)
    .subscribe();

  /* ------------------------------------------------------------------ boot */
  sb.auth.getSession().then(function (r) {
    Cloud.session = r.data ? r.data.session : null;
    loadAll();
  });
  sb.auth.onAuthStateChange(function (_e, session) {
    Cloud.session = session;
    loadAll();
  });
})();
