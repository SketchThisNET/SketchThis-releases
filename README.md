# SketchThis downloads

Signed releases of the **SketchThis** kitchen design plugin for SketchUp, and of the
**SketchThis Updater** that keeps it up to date.

## Get automatic updates

Install the updater once and it takes care of the rest.

1. Open the [Releases page](https://github.com/SketchThisNET/SketchThis-releases/releases) and
   download the newest `SketchThisUpdater_vX.Y.Z.rbz`.
2. In SketchUp, open **Extensions > Extension Manager**, click **Install Extension**, and choose
   the file you downloaded.
3. Restart SketchUp.

Each time SketchUp starts, the updater checks this page for a newer SketchThis (and a newer
updater). When there is one it asks before installing anything. After an update installs, restart
SketchUp to finish.

You can also check at any time from **Extensions > SketchThis Updater > Check for Updates…**.

## Install SketchThis by hand

Prefer not to use the updater? Download the newest `SketchThis_vX.Y.Z.rbz` from the
[Releases page](https://github.com/SketchThisNET/SketchThis-releases/releases) and install it the
same way through Extension Manager.

## Help

Questions or problems: <https://app.sketchthis.net/help>

---

<sub>For maintainers: `manifest.json` is what installed updaters read, and `publish.sh` creates a
release and updates it. Run `./publish.sh --help`.</sub>
