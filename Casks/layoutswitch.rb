cask "layoutswitch" do
  version "1.0.0"
  sha256 "85dc443b3868f6dcbe8260c5f9a43993b7c5c4a11c8f5615b33b44c8258d7c23"

  url "https://github.com/lukdut/LayoutSwitch/releases/download/v#{version}/LayoutSwitch-#{version}-macos-arm64.zip"
  name "LayoutSwitch"
  desc "Switch keyboard layouts with a custom shortcut"
  homepage "https://github.com/lukdut/LayoutSwitch"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "LayoutSwitch.app"

  uninstall quit: "local.masos.LayoutSwitch"

  zap trash: "~/Library/Preferences/local.masos.LayoutSwitch.plist"

  caveats <<~EOS
    Grant LayoutSwitch Input Monitoring access in:
      System Settings > Privacy & Security > Input Monitoring

    This release is ad hoc signed and is not notarized by Apple.
    If macOS blocks the first launch, use Open Anyway in Privacy & Security
    only if you trust the download.

    Before uninstalling, disable launch at login in LayoutSwitch settings.
  EOS
end
