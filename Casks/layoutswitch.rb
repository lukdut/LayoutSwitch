cask "layoutswitch" do
  version "1.1.0"
  sha256 "fa76d54b9e22ee08cdd49b601de1bc93e1f7d2f2dd1407c31e8f571cc437b032"

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
