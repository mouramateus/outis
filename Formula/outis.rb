class Outis < Formula
  desc "Per-country VPN for your phone, running on your Mac (Tor + ProtonVPN Free)"
  homepage "https://github.com/mouramateus/outis"
  url "https://github.com/mouramateus/outis/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "SHA256_PENDENTE"
  license "MIT"
  head "https://github.com/mouramateus/outis.git", branch: "main"

  depends_on :macos
  depends_on macos: :sonoma
  depends_on "qrencode"
  depends_on "tor"

  def install
    ENV["SWIFT_BUILD_FLAGS"] = "--disable-sandbox"
    system "app/build.sh", "--sem-instalar"
    prefix.install "app/dist/Outis.app"
    (bin/"outis").write <<~SH
      #!/bin/bash
      exec "#{opt_prefix}/Outis.app/Contents/Resources/cli/vpn" "$@"
    SH
  end

  def caveats
    <<~EOS
      To add Outis to /Applications (Launchpad and Spotlight):
        ln -sfn "#{opt_prefix}/Outis.app" /Applications/Outis.app

      The phone route needs OrbStack; the VPN account needs Tor Browser:
        brew install --cask orbstack tor-browser

      The command line is available as `outis` (same commands as ./vpn).
    EOS
  end

  test do
    assert_match "Uso:", shell_output("#{bin}/outis help 2>&1")
    assert_path_exists prefix/"Outis.app/Contents/MacOS/VPNPais"
  end
end
