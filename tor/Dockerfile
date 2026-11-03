# Base e versão do Tor fixadas. Para atualizar: troque as duas e rode
#   docker compose -p vpn-pais -f compose-tor.yaml build --pull --no-cache tor
FROM alpine:3.22@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f
RUN apk add --no-cache tor=0.4.9.15-r0 \
 && mkdir -p /var/lib/tor && chown tor:tor /var/lib/tor && chmod 700 /var/lib/tor
COPY torrc /etc/tor/torrc
USER tor
ENTRYPOINT ["tor", "-f", "/etc/tor/torrc"]
