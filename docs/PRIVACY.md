# Privacy

*Last updated October 20, 2026.*

Hermes collects nothing. There is no Hermes account, no Hermes server and no analytics in the Mac app, the iPhone app or the MCP server.

## Your App Store Connect key

Your API key stays on your devices. On the Mac, the `asc` tool keeps it. On iPhone, Hermes keeps it in your Keychain, and iCloud Keychain syncs it between your own devices if you have that turned on. Apple encrypts that end to end. The key itself is never sent anywhere. Hermes uses it to sign short-lived tokens, and those tokens go only to Apple.

## Who Hermes talks to

Only Apple: `api.appstoreconnect.apple.com` for your apps, and Apple's own servers for app icons and store pages. Links to GitHub, the docs or email open in your browser or mail app.

## The website

hermes.jaybulb.com is a static site on Cloudflare. It sets no cookies and runs no analytics. Cloudflare may keep standard request logs, like any web host, under [its own policy](https://www.cloudflare.com/privacypolicy/).

## Email

If you send feedback, I get your email address and what you wrote. I use it to reply, and nothing else.

## Changes

If this ever changes, this page changes first, with a new date at the top.

## Contact

Joshua Trommel, [trommatic@icloud.com](mailto:trommatic@icloud.com).
