cask "layoutswitch" do
  version "1.2.2"
  sha256 "e40d93002e0b6aeec0c2aaa974b12fcee2180e45122f62da2b172833eb2a1b08"

  url "https://github.com/lukdut/LayoutSwitch/releases/download/v#{version}/LayoutSwitch-#{version}-macos-arm64.zip"
  name "LayoutSwitch"
  desc "Switch keyboard layouts with configurable shortcuts"
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
