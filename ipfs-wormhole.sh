#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Send/receive encrypted files using IPFS.
#
# The file to send is encrypted with a temporary password, and added to IPFS.
# The IPFS hash, the password and the file name are merged in a key, which can
# be used to retrieve, decrypt and save the content of the file.
#
# Dependencies:
# - pwgen
# - tar
# - gpg
# - ipfs
# - wget

# Check deps

function checkdep() {
  set +e
  CMDPATH="$(command -v "${1:-}")"
  set -e
  if [ -z "$CMDPATH" ]; then
    echo >&2 "${1:-} not found"
    exit 1
  fi
  echo "$CMDPATH"
}

case "${1:-}" in
send)
  PWGENCMD="$(checkdep pwgen)"
  TARCMD="$(checkdep tar)"
  GPGCMD="$(checkdep gpg)"
  IPFSCMD="$(checkdep ipfs)"
  PASSWORD=$($PWGENCMD -1 20)
  FILE=${2:-}
  if [ -d "$FILE" ]; then
    TAG=$(
      $TARCMD -Jc "$FILE" | $GPGCMD --batch --passphrase="$PASSWORD" \
        -c -o - | $IPFSCMD add -Q
    )
    FILE="$FILE".tar.xz
    echo "Directory compressed and sent as $FILE."
  elif [ -f "$FILE" ]; then
    TAG=$($GPGCMD --batch --passphrase="$PASSWORD" -c -o - "$FILE" |
      $IPFSCMD add -Q)
    echo "File $FILE sent."
  else
    echo "error: $FILE is neither a file, nor a directory"
    exit 1
  fi
  FILENAME="$(echo "$FILE" | base64)"
  FULLTAG="$TAG$PASSWORD$FILENAME"
  RECEIVECMD="$0 receive $FULLTAG"
  echo "Retrieve it with $RECEIVECMD"
  set +e
  XCLIPCMD="$(command -v xclip)"
  set -e
  if [ -n "$XCLIPCMD" ]; then
    echo "$FULLTAG" | $XCLIPCMD
    echo "Copied to clipboard"
  fi
  exit 0
  ;;
receive)
  GPGCMD="$(checkdep gpg)"
  IPFSCMD="$(checkdep ipfs)"
  DSTFILENAME="$(echo "${2:66}" | base64 -d)"
  if [ -f "$DSTFILENAME" ]; then
    echo "File $DSTFILENAME already exists, aborting..."
    exit 1
  fi
  echo "Receiving $DSTFILENAME..."
  $IPFSCMD cat "${2:0:46}" |
    $GPGCMD --batch --passphrase="${2:46:20}" -d \
      >"$DSTFILENAME" \
      2>/dev/null
  exit 0
  ;;
checkdeps)
  PWGENCMD="$(checkdep pwgen)"
  TARCMD="$(checkdep tar)"
  GPGCMD="$(checkdep gpg)"
  IPFSCMD="$(checkdep ipfs)"
  WGETCMD="$(checkdep wget)"
  echo "Everything looks good"
  exit 0
  ;;
update)
  WGETCMD="$(checkdep wget)"
  echo Update...
  $WGETCMD -O "${0:-}" \
    https://raw.githubusercontent.com/aurelg/ipfs-wormhole/master/ipfs-wormhole.sh
  chmod +x "${0:-}"
  exit 0
  ;;
*)
  cat <<EOM
Get things from one computer to another, safely. Over IPFS.

On machine A
------------

${0:-} send <file or directory>

Will encrypt and add the file (or the directory as a compressed tarball) to
IPFS, and output a tag. If xclip is installed, the command to retrieve it will
be copied to the clipboard.

On machine B
------------

${0:-} receive <tag>

Check dependencies
-----------------------

${0:-} checkdeps

Update from github repo
-----------------------

${0:-} update
EOM
  ;;
esac
