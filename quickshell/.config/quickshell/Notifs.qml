pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Notification daemon. Owns org.freedesktop.Notifications, the visible card stack,
// and the queue of notifications that arrived while a popout was covering the stack.
//
// Lifetime rule that shapes this whole file: a Notification is destroyed the moment
// it stops being tracked (`tracked = false` is literally dismiss()), and an app that
// calls CloseNotification frees it out from under us. So delegates never bind to a
// Notification -- present() copies the display fields into a record and keeps only a
// guarded pointer, which onClosed() nulls before the object goes away. That lets a
// card keep painting through its exit animation after the notification is long gone.
Singleton {
    id: root

    // ── Policy ───────────────────────────────────────────────────────
    // Every urgency clears within maxTimeout, Critical included. expireTimeout arrives
    // as the raw D-Bus value in MILLISECONDS (verified: notify-send -t 3000 delivers
    // 3000), where 0 means "never expire" and -1 means "server decides". The `> 0` test
    // sends both to the cap, so an app can ask for less than 8s but never for more.
    readonly property int maxTimeout: 8000
    readonly property int maxVisible: 5

    // Visible stack, newest first. ScriptModel diffs by object identity, so a prepend
    // builds exactly one delegate and the cards already on screen keep their in-flight
    // animations instead of being torn down and rebuilt.
    readonly property ScriptModel model: ScriptModel { id: stack; values: [] }

    NotificationServer {
        id: server

        // Quickshell rebuilds all QML on every file save, which destroys the cards'
        // timers and animation state. Kept notifications would survive in the server
        // with no delegate to show or clear them, and their timers would restart on
        // each save -- so a notification could outlive the cap. Drop them instead.
        keepOnReload: false

        actionsSupported: true
        bodySupported:    true
        imageSupported:   true
        // Bodies render as literal text (see NotificationCard's textFormat).
        bodyMarkupSupported: false

        onNotification: (n) => root.present(n)
    }

    // ── Hold: a popout is covering the stack ─────────────────────────
    // The quicksettings and battery popouts are top-right layer surfaces at the same
    // origin as the notification stack, so they collide. Rather than let them overlap,
    // Bar registers a hold while either is open: arrivals queue, and the cards already
    // on screen freeze their countdowns. Nothing is lost -- present() acks each
    // notification before it branches, so a held notification is invisible to us, not
    // to the app that sent it.
    property var holders: []                     // Bar instances with a popout open
    property var pending: []                     // arrived while held, capped at maxVisible
    readonly property bool held: holders.length > 0

    // Deferred, not immediate: switching straight from one popout to the other drops the
    // hold for a single statement (see drain()). Qt.callLater collapses that transient.
    onHeldChanged: if (!held) Qt.callLater(root.drain)

    function setHold(key, on) {
        if (on && root.holders.indexOf(key) < 0)
            root.holders = root.holders.concat([key]);
        else if (!on)
            root.holders = root.holders.filter((k) => k !== key);
    }

    // ── Records ──────────────────────────────────────────────────────
    Component {
        id: recordComp

        QtObject {
            id: rec
            property var    notif                // live Notification; nulled once closed
            property var    onClosed             // signal handlers, kept so teardown can unhook them
            property var    onUpdated
            property string summary
            property string body
            property string appName
            property string appIcon
            property string image
            property int    timeout              // ms, already capped
            property bool   hovered: false       // a card somewhere is under the pointer
            property bool   dismissing: false    // ask the cards to animate out
            property bool   reaping: false       // teardown already scheduled; do not double-remove

            // The countdown belongs to the RECORD, not to a card. Variants builds one Bar
            // per monitor, so there is one NotificationCard per monitor, and every one of
            // them repeats over this same shared model -- a per-card timer would run once
            // per screen. Worse, the copies on unfocused monitors sit in unmapped windows
            // and can never see the pointer, so their timers would never pause on hover:
            // they would run to term and reap the record out from under the card the user
            // is actually reading. One record, one countdown, one owner.
            property PauseAnimation life: PauseAnimation {
                duration: rec.timeout
                // Guarded on `running`: setPaused() warns when the animation is stopped,
                // and this binding is first evaluated before running latches.
                paused: running && (rec.hovered || root.held)
                onFinished: rec.dismissing = true
            }
        }
    }

    function present(n) {
        // Untracked notifications are discarded by the server, so this is both the ack
        // and what keeps the object alive long enough to invoke its actions.
        n.tracked = true;

        var rec = recordComp.createObject(root, { notif: n });
        root.copy(rec, n);

        // Fires just before the server frees the notification -- i.e. when the APP closes
        // it. Drop the pointer first so nothing can dereference freed memory; the copied
        // fields keep the card painted for the rest of its exit animation. Kept on the
        // record so teardown can unhook it before it tears the cards down.
        rec.onClosed = () => {
            rec.notif = null;
            rec.dismissing = true;
        };
        n.closed.connect(rec.onClosed);

        // An app REPLACING a notification (notify-send -r, download progress, a chat client
        // collapsing "N new messages") reuses the same D-Bus id, and the server mutates the
        // existing Notification in place rather than emitting a new one -- present() never
        // runs again for it. Without these hooks the card would keep painting the original
        // text for the rest of its life while its action buttons, which do bind to the live
        // object, silently swapped to the new ones. Re-copy instead, and re-arm.
        rec.onUpdated = () => {
            if (!rec.notif) return;
            root.copy(rec, rec.notif);
            // Only if it is already on screen: a queued record must not start counting
            // down before it is shown. show() starts it, with the refreshed duration.
            if (rec.life.running) rec.life.restart();
        };
        n.summaryChanged.connect(rec.onUpdated);
        n.bodyChanged.connect(rec.onUpdated);
        n.appNameChanged.connect(rec.onUpdated);
        n.appIconChanged.connect(rec.onUpdated);
        n.imageChanged.connect(rec.onUpdated);
        n.expireTimeoutChanged.connect(rec.onUpdated);

        if (root.held) root.enqueue(rec);
        else           root.show(rec);
    }

    // Snapshot the display fields. Called on arrival and again on every in-place update.
    function copy(rec, n) {
        rec.summary = n.summary;
        rec.body    = n.body;
        rec.appName = n.appName;
        rec.appIcon = n.appIcon;
        rec.image   = n.image;
        rec.timeout = n.expireTimeout > 0 ? Math.min(n.expireTimeout, root.maxTimeout)
                                          : root.maxTimeout;
    }

    // Stop observing the notification. Returns the (still live) Notification, or null.
    // Both teardown paths call this FIRST: dismiss() makes the server emit closed, and the
    // handlers would otherwise write to a record that is already on its way out.
    function unhook(rec) {
        var n = rec.notif;
        if (!n) return null;
        if (rec.onClosed) n.closed.disconnect(rec.onClosed);
        if (rec.onUpdated) {
            n.summaryChanged.disconnect(rec.onUpdated);
            n.bodyChanged.disconnect(rec.onUpdated);
            n.appNameChanged.disconnect(rec.onUpdated);
            n.appIconChanged.disconnect(rec.onUpdated);
            n.imageChanged.disconnect(rec.onUpdated);
            n.expireTimeoutChanged.disconnect(rec.onUpdated);
        }
        return n;
    }

    function show(rec) {
        stack.values = [rec].concat(stack.values);
        // The countdown measures ON-SCREEN time, so it starts here rather than on arrival:
        // a record that waited in the queue gets its full life once the popout closes.
        rec.life.running = true;
        // Overflow: flag EVERY card past the cap, not just the oldest one. A burst lands
        // several arrivals before the first has finished animating out, so flagging a
        // single card per arrival re-flags the same one and settles a card too tall.
        // Setting dismissing on an already-dismissing card is a no-op.
        var v = stack.values;
        for (var i = root.maxVisible; i < v.length; i++) v[i].dismissing = true;
    }

    function enqueue(rec) {
        var q = root.pending.concat([rec]);
        // Drop the oldest queued notifications, not the newest arrivals: a burst that outlasts
        // the popout is worth reading from its tail, not its head. The cap mirrors maxVisible
        // because a drain cannot put more cards on screen than the stack shows anyway --
        // anything past it is flagged `dismissing` by show() and animates straight back out
        // without ever having been read, so queueing it only to bin it is wasted motion.
        while (q.length > root.maxVisible) root.discard(q.shift());
        root.pending = q;
    }

    // Oldest first, prepending each, so the newest arrival lands on top of the stack.
    function drain() {
        // Clicking one popout while the other is open assigns both `shown` flags in
        // sequence, so Bar's popoutOpen binding goes false for a single statement before
        // going true again -- dropping the hold, and landing here. Re-check (this is called
        // deferred, see onHeldChanged) so the queue does not flush into a stack that is
        // still covered: every card would play its reveal into an unmapped surface, and any
        // pushed past the cap would animate out and be reaped without ever being drawn.
        if (root.held) return;

        var q = root.pending;
        root.pending = [];
        for (var i = 0; i < q.length; i++) {
            if (q[i].dismissing) root.discard(q[i]);   // closed while queued; never shown
            else                 root.show(q[i]);
        }
    }

    function discard(rec) {
        var n = root.unhook(rec);
        if (n) n.dismiss();
        rec.destroy();
    }

    // Called by a card once its collapse animation has finished -- which means we run
    // INSIDE that card's own animation callback (the ScriptAction at the tail of its
    // Behavior). Splicing the record here would destroy that very card synchronously,
    // mid-callback, and Qt would then unwind the still-running animation job against a
    // context it had just torn down: "QQmlExpression: Attempted to evaluate an expression
    // in an invalid context", twice per card. So the teardown is deferred a tick, letting
    // the animation unwind before its delegate goes away.
    //
    // The rest is ordered too: unhook first, then splice so the ScriptModel diff tears the
    // delegates down, then -- one more tick later, once nothing can read either -- free the
    // notification and the record.
    //
    // `reaping` also absorbs the duplicate calls that arrive with several monitors: every
    // screen has its own card for this record, and they all collapse and call in.
    function remove(rec) {
        if (rec.reaping || stack.values.indexOf(rec) < 0) return;   // timeout and close can both fire
        rec.reaping = true;

        Qt.callLater(() => {
            var n = root.unhook(rec);

            stack.values = stack.values.filter((r) => r !== rec);
            Qt.callLater(() => {
                // Reap the record BEFORE dismissing. unhook() stopped us hearing `closed`, so
                // if the app calls CloseNotification in the tick between these two callbacks
                // the server frees the notification and `n` is left dangling -- and a dangling
                // ref is still truthy, so `if (n)` passes and dismiss() throws. Ordering the
                // destroy first means that throw can no longer skip it and strand the record.
                rec.destroy();
                if (n) n.dismiss();
            });
        });
    }
}
