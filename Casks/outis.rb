cask "outis" do
  version "1.0.0"
  sha256 "11f8dab67600a73e4ad4dfe2e5335306089cfa9b9ec7866853019fea20e97e73"

  url "https://github.com/mouramateus/outis/releases/download/v#{version}/Outis-#{version}.zip"
  name "Outis"
  desc "Per-country VPN for your phone, running on your Mac (Tor + ProtonVPN Free)"
  homepage "https://github.com/mouramateus/outis"

  depends_on macos: ">= :sonoma"
  depends_on formula: "tor"
  depends_on formula: "qrencode"

  app "Outis.app"
  binary "#{appdir}/Outis.app/Contents/Resources/cli/vpn", target: "outis"

  # The app is not notarized (ad-hoc signed): drop the quarantine flag so macOS opens it.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Outis.app"]
  end

  uninstall quit: "io.github.mouramateus.outis"

  zap trash: [
    "~/Library/Application Support/vpn-pais",
    "~/Library/Preferences/io.github.mouramateus.outis.plist",
  ]

  caveats <<~EOS
    The phone route needs OrbStack; the VPN account needs Tor Browser:
      brew install --cask orbstack tor-browser

    The command line is available as `outis`.
  EOS
end
