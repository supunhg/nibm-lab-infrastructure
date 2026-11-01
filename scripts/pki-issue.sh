#!/usr/bin/env bash
# NIBM Homelab internal PKI.
#   - Root CA (10 y), name-constrained to *.lab + campus/ZeroTier IPs: safe to install on student devices.
#   - Server cert listing every *.lab host from AdGuard rewrites (browsers reject a bare *.lab wildcard: .lab is a public TLD).
#   - Installs into NPM (same filenames all proxy hosts already use) and builds a trust bundle for containers.
# usage: sudo pki-issue [--force]      (renews automatically when < 60 days left; run by pki-renew.timer)
set -euo pipefail
P=/opt/homelab/pki; NPM=/opt/homelab/npm/data/custom_ssl; ADG=/opt/homelab/adguard/conf/AdGuardHome.yaml
mkdir -p $P; chmod 755 $P; cd $P

if [ ! -f ca.key ]; then
  openssl genrsa -out ca.key 4096 2>/dev/null; chmod 600 ca.key
  openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=NIBM Homelab Root CA/O=NIBM Homelab" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "nameConstraints=critical,permitted;DNS:.lab,permitted;DNS:lab,permitted;IP:192.168.0.0/255.255.0.0,permitted;IP:10.147.17.0/255.255.255.0"
  echo "created root CA"
fi

if [ "${1:-}" != "--force" ] && [ -f server.crt ] && openssl x509 -checkend $((60*86400)) -noout -in server.crt >/dev/null; then
  echo "server cert valid > 60 days, nothing to do"; exit 0
fi

HOSTS=$(grep -oE 'domain: [a-z0-9.-]+\.lab' $ADG | awk '{print $2}' | sort -u)
SAN=$(printf 'DNS:%s,' $HOSTS)"IP:192.168.1.10,IP:10.147.17.10"
openssl genrsa -out server.key 2048 2>/dev/null; chmod 600 server.key
openssl req -new -key server.key -out server.csr -subj "/CN=home.lab/O=NIBM Homelab"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 397 -sha256 \
  -extfile <(printf "basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=%s\n" "$SAN") 2>/dev/null
rm -f server.csr
openssl verify -CAfile ca.crt server.crt >/dev/null

# NPM: keep the filenames every proxy host references
[ -f $NPM/lab_wildcard.crt.pre-pki ] || cp $NPM/lab_wildcard.crt $NPM/lab_wildcard.crt.pre-pki
[ -f $NPM/lab_wildcard.key.pre-pki ] || cp $NPM/lab_wildcard.key $NPM/lab_wildcard.key.pre-pki
cat server.crt ca.crt > $NPM/lab_wildcard.crt; cp server.key $NPM/lab_wildcard.key; chmod 600 $NPM/lab_wildcard.key
cp ca.crt $NPM/nibm-root-ca.crt; chmod 644 $NPM/nibm-root-ca.crt

# trust bundle for containers (system roots + our CA) and the host itself
cat /etc/ssl/certs/ca-certificates.crt ca.crt > trust-bundle.crt; chmod 644 trust-bundle.crt ca.crt
cp ca.crt /usr/local/share/ca-certificates/nibm-homelab-root-ca.crt && update-ca-certificates >/dev/null 2>&1

docker exec nginx-proxy-manager nginx -s reload
echo "issued server cert for $(echo $HOSTS | wc -w) hosts, expires $(openssl x509 -enddate -noout -in server.crt | cut -d= -f2)"
