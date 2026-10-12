#!/bin/sh
# Creates a self-signed code signing certificate named "Lugbara Local" in the login keychain.
# `make app` signs with it when it exists, so macOS keeps the app's permissions across builds.
# The certificate only works on this Mac. Delete it in Keychain Access under "My Certificates".
set -eu

NAME="Lugbara Local"
if security find-identity -p codesigning | grep -q "\"$NAME\""; then
    echo "The certificate \"$NAME\" already exists."
    exit 0
fi

DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT

cat > "$DIR/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$DIR/cert.cnf" \
    -keyout "$DIR/key.pem" -out "$DIR/cert.pem" 2>/dev/null
PASSWORD=$(openssl rand -hex 12)
openssl pkcs12 -export -name "$NAME" -inkey "$DIR/key.pem" -in "$DIR/cert.pem" \
    -out "$DIR/cert.p12" -passout "pass:$PASSWORD"
security import "$DIR/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "$PASSWORD" -T /usr/bin/codesign
echo "Created \"$NAME\". Run make install to build and sign with it."
