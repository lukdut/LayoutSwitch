cask "layoutswitch" do
  version "1.0.1"
  sha256 "a97ccb540a671dbd46d1854b6bddf205f803d9f527a4d31c280dac9ce62a51e1"

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
    After an update, macOS may require granting this permission again.

    This release is ad hoc signed and is not notarized by Apple.
    If macOS blocks the first launch, use Open Anyway in Privacy & Security
    only if you trust the download.

    Before uninstalling, disable launch at login in LayoutSwitch settings.
  EOS
end
