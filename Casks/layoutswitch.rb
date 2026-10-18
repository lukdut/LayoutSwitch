cask "layoutswitch" do
  version "1.2.1"
  sha256 "381ab82013fda917443018accda7fa4be7984f5d098e80b372f1474b6a33ffed"

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
