---
name: hermes-resolve
description: Answer open App Store rejections with Hermes outside the app. Reads every open Resolution Center thread, pulls checked facts per app (versions App Review approved, builds, the app's own Swift files, files shared with other apps, README), drafts each reply on the Mac's on-device model, and sends one only on Joshua's yes. Use for /hermes-resolve, "answer the rejections", "reply to Apple", "resolve all", or any 4.3 spam appeal.
---

# Hermes resolve

Resolve All from the Mac app, as steps an agent can run. Read only until Joshua says send.

1. **Find the open threads.** With the `hermes` MCP connected, call `fleet_status`, then `open_rejections` for each app with a rejected version. Without it: `ASC_BYPASS_KEYCHAIN=1 asc web review show --app <id> --plain-text`. If the Apple web session has expired, ask Joshua once to run `asc web auth login` (his password and code, never typed for him).
2. **Check the name.** The store listing can lag a rename (Thinkpond is Melete, Sidewise became Bugle). Reply with the name Apple sees, and skip any app Joshua has folded into another one.
3. **Get the facts.** `app_facts <id>` gives the review history, the versions already approved, the build count and first upload, the source repo, the app's own Swift files and any byte-identical with other apps, and the README. Never write a fact that is not in that output.
4. **Draft.** `scripts/try-writer.sh "<App> <version>" "<reasons>" facts.txt apple.txt` runs Hermes' Writer on Apple's on-device model (Ollama if Apple Intelligence is off). A plain 4.3(a) gets the house reply: what the app is, the checked file facts word for word, then a question about which apps were found similar. Apple's nine-question 4.3 follow-up gets nine numbered answers, one fact each.
5. **Read it like a reviewer.** Every number has to match `app_facts`. Cut anything the facts do not show. Never claim a change that was not made, and never say another app on the account covers different ground unless you checked it.
6. **Send only on Joshua's yes**, for that exact text: `send_rejection_reply` with `HERMES_ALLOW_WRITES=1`, or `asc web review reply --thread-id <id> --message @file:<path> --confirm`. One send. Never retry: Apple may have taken a send that reported an error. Report the `messageId` and `verified`.

Never resubmit a build from this skill. Submissions go through /hermes-ship.
