# everything-app
The app so I can track everything I would ever want to track.

## Building

Plain SwiftPM plus a Makefile, no Xcode project. Xcode.app still has to be
installed for the iOS SDK; the Makefile points at it directly.

```
make ipa   # unsigned build/Everything.ipa for the phone
make sim   # build, install and launch in the iOS Simulator
```

The IPA is deliberately unsigned. AirDrop it to the phone and open it in
SideStore, which signs it with the free Personal Team certificate and keeps it
refreshed. Reinstalling the same bundle ID keeps the SQLite database.

Data lives in one SQLite file in the app's Application Support directory.

## Shipping to the phone

```
make release
```

Builds the IPA, publishes it as a GitHub Release, and updates `source.json`,
which SideStore polls. The version is `VERSION` plus the commit count, so it
always moves forward. Requires a clean tree on `main` and the `gh` CLI.

One-time setup on the phone, in Safari:

    sidestore://source?url=https://raw.githubusercontent.com/eshaan-mehta/everything-app/main/source.json

After that every release appears as an update in SideStore. Tap Update and the
new build installs over the old one, keeping the database.
