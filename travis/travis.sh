#!/bin/bash -e
#
# From the GitHub repository:
# https://github.com/openSUSE/doc-ci
#
# License: MIT
#
# Written by Thomas Schraitle

VERSION="v0.9.0"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[33;1m'
BOLD='\033[1m'
NC='\033[0m' # No Color

DCVALIDATE=".travis-check-docs"
DCBUILD=".travis-build-docs"

DAPS="daps"
# Setting --styleroot makes sure that DAPS does not error out when the
# stylesheets requested by the DC file are not available in the container.
DAPS_SR="$DAPS --styleroot /usr/share/xml/docbook/stylesheet/suse2013-ns/"


log() {
  # $1 - message
  echo -e "$YELLOW$BOLD${1}$NC"
}

fail() {
  # $1 - message
  echo -e "$RED$BOLD${1}$NC"
  exit 1
}

succeed() {
  # $1 - message
  echo -e "$GREEN$BOLD${1}$NC"
  exit 0
}


mkdir -p /root/.config/daps/
echo DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc" > /root/.config/daps/dapsrc

source env.list
PRODUCT=$(echo $TRAVIS_BRANCH | sed -e 's/maintenance\///g')
REPO=$(echo $TRAVIS_REPO_SLUG | sed -e 's/.*\///g')
echo "TRAVIS_REPO_SLUG=\"$TRAVIS_REPO_SLUG\""
echo "REPO=\"$REPO\""
echo "TRAVIS_BRANCH=\"$TRAVIS_BRANCH\""
echo "PRODUCT=\"$PRODUCT\""
echo "TRAVIS_PULL_REQUEST=\"$TRAVIS_PULL_REQUEST\""
echo "PUBLISH_PRODUCTS=\"$PUBLISH_PRODUCTS\""

if [ $LIST_PACKAGES -eq "1" ] ; then
  rpm -qa | sort
fi

DCLIST=$(ls DC-*-all)
if [[ -f "$DCVALIDATE" ]]; then
    DCLIST=$(cat "$DCVALIDATE")
elif [ -z "$DCLIST" ] ; then
    DCLIST=$(ls DC-*)
fi

# Do this first, so this fails as quickly as possible.
unavailable=
for DCFILE in $DCLIST; do
    [[ ! -f $DCFILE ]] && unavailable+="$DCFILE "
done
if [[ ! -z $unavailable ]]; then
    fail "DC file(s) is/are configured in $DCVALIDATE but not present in repository:\n$unavailable"
fi

echo -e '\n'
for DCFILE in $DCLIST; do
    log "Validating $DCFILE (with $(rpm -qv geekodoc))...\n"
    $DAPS_SR -vv -d $DCFILE validate || exit 1
    log "\nChecking for missing images in $DCFILE ...\n"
    MISSING_IMAGES=$($DAPS_SR -d $DCFILE list-images-missing)
    if [ -n "$MISSING_IMAGES" ]; then
        fail "Missing images:\n$MISSING_IMAGES"
    else
        log "All images available."
    fi
    echo -e '\n\n\n'
    wait
done

if [[ -f "$DCBUILD" ]]; then
    DCBUILDLIST=$(cat "$DCBUILD")
else
    succeed "No DC files to build.\nExiting cleanly now.\n"
fi

re='^[0-9]+$'
if [[ $TRAVIS_PULL_REQUEST ~=$re ]]; then
    succeed "This is a Pull Request.\nExiting cleanly now.\n"
fi

if [[ ! $(echo "$PUBLISH_PRODUCTS" | grep -w "$PRODUCT" 2> /dev/null) ]]; then
    succeed "This branch is not configured for builds: $TRAVIS_BRANCH\nExiting cleanly now.\n"
fi




# Decrypt the SSH private key
openssl aes-256-cbc -pass "pass:$ENCRYPTED_PRIVKEY_SECRET" -in ./ssh_key.enc -out ./ssh_key -d -a
# SSH refuses to use the key if its readable to the world
chmod 0600 ssh_key
# Start the SSH authentication agent
eval $(ssh-agent -s)
# Display the key fingerprint from the file
ssh-keygen -lf ssh_key
# Import the private key
ssh-add ssh_key
# Display fingerprints of available SSH keys
ssh-add -l

# Set the git username and email used for the commits
git config --global user.name "Travis CI"
git config --global user.email "$COMMIT_AUTHOR_EMAIL"

# Build HTML and single HTML as drafts
for DCFILE in $DCBUILDLIST; do
    styleroot=$(grep -P '^\s*STYLEROOT\s*=\s*' $DCFILE | sed -r -e 's/^[^=]+=\s*["'\'']//' -e 's/["'\'']\s*//')
    dapsbuild=$DAPS
    if [[ ! -d "$styleroot" ]]; then
      dapsbuild=$DAPS_SR
      log "$DCFILE requests style root $styleroot which is not installed. Replacing with default style root."
    fi
    log "\nBuilding HTML for $DCFILE ...\n"
    $dapsbuild -d $DCFILE html --draft
    log "\nBuilding single HTML for $DCFILE ...\n"
    $dapsbuild -d $DCFILE html --single --draft
    wait
done

# Now clone the GitHub pages repository, checkout the gh-pages branch and clean files
mkdir ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts
log "Cloning GitHub Pages repository\n"
git clone ssh://git@github.com/SUSEdoc/$REPO.git /tmp/$REPO
git -C /tmp/$REPO/ checkout gh-pages
rm -r /tmp/$REPO/$PRODUCT

# Copy the HTML and single HTML files for each DC file
for DCFILE in $DCBUILDLIST; do
    MVFOLDER=$(echo $DCFILE | sed -e 's/DC-//g')
    log "Moving $DCFILE...\n"
    echo "mkdir -p /tmp/$REPO/$PRODUCT/$MVFOLDER"
    mkdir -p /tmp/$REPO/$PRODUCT/$MVFOLDER/html /tmp/$REPO/$PRODUCT/$MVFOLDER/single-html
    echo "mv /usr/src/app/build/$MVFOLDER/html /tmp/$REPO/$PRODUCT/$MVFOLDER/"
    mv /usr/src/app/build/$MVFOLDER/html/*/* /tmp/$REPO/$PRODUCT/$MVFOLDER/html/
    echo "mv /usr/src/app/build/$MVFOLDER/single-html /tmp/$REPO/$PRODUCT/$MVFOLDER/"
    mv /usr/src/app/build/$MVFOLDER/single-html/*/* /tmp/$REPO/$PRODUCT/$MVFOLDER/single-html/
    echo -e '\n\n\n'
    wait
done

# Add all changed files to the staging area, commit and push
git -C /tmp/$REPO add -A .
echo "git -C /tmp/$REPO commit -m \"Deploy to GitHub Pages: ${TRAVIS_COMMIT}\""
git -C /tmp/$REPO commit -m "Deploy to GitHub Pages: ${TRAVIS_COMMIT}"
echo "git -C /tmp/$REPO push"
git -C /tmp/$REPO push
