import argparse
import subprocess
from pathlib import Path

from dmgbuild import build_dmg
from ds_store import DSStore
from mac_alias import Bookmark


def verify_layout(volume):
    volume = Path(volume)
    with DSStore.open(str(volume / ".DS_Store"), "r") as store:
        options = store["."]["icvp"]
        window = store["."]["bwsp"]
        assert options["backgroundType"] == 2
        assert options["backgroundImageAlias"]
        bookmark = store["."]["pBBk"]
        assert bookmark is not None
        assert options["iconSize"] == 112
        assert options["gridSpacing"] < 100
        assert store["Say.app"]["Iloc"] == (224, 286)
        assert store["Applications"]["Iloc"] == (536, 286)
        assert window["WindowBounds"] == "{{200, 140}, {760, 528}}"
        assert not any(window[key] for key in ["ShowToolbar", "ShowSidebar", "ShowStatusBar"])
    assert (volume / "Applications").is_symlink()
    assert (volume / "Applications").readlink() == Path("/Applications")
    assert (volume / ".VolumeIcon.icns").is_file()
    assert (volume / ".background.tiff").is_file()
    resolved = subprocess.run(
        ["swift", "-e", """
import AppKit
var stale = false
let data = FileHandle.standardInput.readDataToEndOfFile()
let url = try URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting],
                  relativeTo: nil, bookmarkDataIsStale: &stale)
guard let image = NSImage(contentsOf: url), image.isValid,
      image.size == NSSize(width: 760, height: 500) else {
    fatalError("Installer background cannot be loaded.")
}
let markURL = url.deletingLastPathComponent()
    .appendingPathComponent("Say.app/Contents/Resources/SayMark.pdf")
guard let mark = NSImage(contentsOf: markURL), mark.isValid,
      mark.size == NSSize(width: 100, height: 100) else {
    fatalError("Say's vector mark is missing or invalid.")
}
print(url.path)
"""],
        input=bookmark.to_bytes(), capture_output=True, check=True,
    )
    assert Path(resolved.stdout.decode().strip()) == volume / ".background.tiff"
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(volume / "Say.app")], check=True)


def package(app, background, output):
    app, background, output = (Path(path).resolve() for path in (app, background, output))
    if output.exists():
        raise FileExistsError(f"Installer already exists: {output}")
    if not app.is_dir() or not background.is_file():
        raise FileNotFoundError("Build Say and its artwork before packaging.")
    mounted = None

    def remember_volume(path, _options):
        nonlocal mounted
        mounted = path

    def check_layout(event):
        if event.get("type") == "operation::finished" and event.get("operation") == "dsstore::create":
            bookmark = subprocess.check_output([
                "swift", "-e", """
import Foundation
let url = URL(fileURLWithPath: CommandLine.arguments.last!)
let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
FileHandle.standardOutput.write(bookmark)
""", str(Path(mounted) / ".background.tiff")])
            with DSStore.open(str(Path(mounted) / ".DS_Store"), "r+") as store:
                store["."]["pBBk"] = Bookmark.from_bytes(bookmark)
            verify_layout(mounted)

    build_dmg(
        str(output),
        "Say",
        settings={
            "format": "UDZO",
            "compression_level": 9,
            "filesystem": "HFS+",
            "size": "32m",
            "files": [str(app)],
            "symlinks": {"Applications": "/Applications"},
            "icon": str(app / "Contents/Resources/AppIcon.icns"),
            "background": str(background),
            "window_rect": ((200, 140), (760, 528)),
            "default_view": "icon-view",
            "icon_size": 112,
            "text_size": 14,
            "grid_spacing": 54,
            "show_icon_preview": True,
            "icon_locations": {"Say.app": (224, 286), "Applications": (536, 286)},
            "create_hook": remember_volume,
        },
        callback=check_layout,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", metavar="VOLUME")
    parser.add_argument("paths", nargs="*")
    arguments = parser.parse_args()
    if arguments.verify:
        verify_layout(arguments.verify)
        print("Installer layout and app signature verified.")
    elif len(arguments.paths) == 3:
        package(*arguments.paths)
    else:
        parser.error("provide APP BACKGROUND OUTPUT, or --verify VOLUME")
