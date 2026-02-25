#!/bin/sh
set -e

eval "$(jq -er '@sh "VERSION=\(.version)
                    ENABLED_FUNCTION=\(.enabled_function)
                    ARCHITECTURE=\(.architecture)
                    CACHE_DIR=\(.cache_dir)"')"

SYSTEM="$(uname | awk '{print tolower($0)}')"
FUNCTION_BEAT_URL=https://artifacts.elastic.co/downloads/beats/functionbeat/functionbeat-"${VERSION}"-"${SYSTEM}"-"${ARCHITECTURE}".tar.gz

DESTINATION=functionbeat-"${VERSION}"-"${SYSTEM}"-"${ARCHITECTURE}"

export BEAT_STRICT_PERMS=false
export ENABLED_FUNCTION="${ENABLED_FUNCTION}"

mkdir -p "${CACHE_DIR}/${ENABLED_FUNCTION}"

# download functionbeat if not already in cache
if [ ! -f "${CACHE_DIR}/${DESTINATION}.tar.gz" ]; then
  mkdir -p "${CACHE_DIR}"
  curl -s -o "${CACHE_DIR}/${ENABLED_FUNCTION}/${DESTINATION}.tar.gz.tmp" "${FUNCTION_BEAT_URL}"
  mv "${CACHE_DIR}/${ENABLED_FUNCTION}/${DESTINATION}.tar.gz.tmp" "${CACHE_DIR}/${DESTINATION}.tar.gz"
fi

cd "${CACHE_DIR}/${ENABLED_FUNCTION}"

tar xzvf "../${DESTINATION}".tar.gz > /dev/null

cp -f "functionbeat.yml" "${DESTINATION}"/functionbeat.yml

cd "${DESTINATION}"
./functionbeat -v -e package --output ./../"${DESTINATION}-release".zip
cd ..
rm -rf "${DESTINATION}"

unzip -o -qq -a "${DESTINATION}"-release.zip -d "${DESTINATION}"-release
rm -rf "${DESTINATION}"-release.zip

cd "${DESTINATION}"-release
# custom runtime requires the executable to be named bootstrap
mv functionbeat-aws bootstrap
chmod go-w functionbeat.yml
cd ..

# zip destination contents and with deterministic file order
find "${DESTINATION}"-release/* -type f | LC_ALL=C sort | zip -j -q -X -@ "${DESTINATION}"-release.zip
rm -rf "${DESTINATION}"-release

FILEHASH=$(openssl dgst -binary -sha256 "${DESTINATION}-release.zip" | openssl base64)

jq -M -c -n --arg filehash "$FILEHASH" --arg destination "${PWD}/${DESTINATION}-release.zip" '{"filename": $destination, "filehash": $filehash}'
