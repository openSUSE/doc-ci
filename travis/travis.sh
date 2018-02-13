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

# Setting --styleroot makes sure that DAPS does not error out when the
# stylesheets requested by the DC file are not available in the container.
DAPS_SR="daps --styleroot /usr/share/xml/docbook/stylesheet/suse2013-ns/"

mkdir -p /root/.config/daps/
echo DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc" > /root/.config/daps/dapsrc

source env.list
PRODUCT=$(echo $TRAVIS_BRANCH | sed -e 's/maintenance\///g')
REPO=$(echo $TRAVIS_REPO_SLUG | sed -e 's/.*\///g')
echo "User/Repo: $TRAVIS_REPO_SLUG"
echo "Repo: $REPO"
echo "Source branch: $SOURCE_BRANCH"
echo "Travis branch: $TRAVIS_BRANCH"
echo "Product: $PRODUCT"
echo "Pull request: $TRAVIS_PULL_REQUEST"

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
    echo "${RED}${BOLD}The following DC file(s) is/are configured in $DCVALIDATE but not present in repository:${NC}"
    echo "${RED}${BOLD}$unavailable${NC}"
    exit 1
fi

echo =e '\n'
for DCFILE in $DCLIST; do
    echo -e "${YELLOW}${BOLD}Validating $DCFILE (with $(rpm -qv geekodoc))...${NC}\n"
    $DAPS_SR -vv -d $DCFILE validate || exit 1
    echo -e "\n${YELLOW}${BOLD}Checking for missing images in $DCFILE ...${NC}\n"
    MISSING_IMAGES=$($DAPS_SR -d $DCFILE list-images-missing)
    if [ -n "$MISSING_IMAGES" ]; then
        echo -e "${RED}${BOLD}Missing images:${NC}"
        echo -e "$MISSING_IMAGES"
        exit 1
    else
        echo -e "${GREEN}All images available.${NC}"
    fi
    echo -e '\n\n\n'
    wait
done

if [[ -f "$DCBUILD" ]] && [[ "$TRAVIS_PULL_REQUEST" ]]; then
    DCBUILDLIST=$(cat "$DCBUILD")
else
    exit 0
fi

if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    if ! echo $PUBLISH_PRODUCTS | grep -w $PRODUCT > /dev/null; then
        echo -e "${YELLOW}${BOLD}Only validating, not building. Current branch: $TRAVIS_BRANCH${NC}\n"
        exit 0
    fi
fi
# Decrypt the SSH private key
openssl aes-256-cbc -pass "pass:$ENCRYPTED_PRIVKEY_SECRET" -in ./ssh_key.enc -out ./ssh_key -d -a
# SSH refuses to use the key if its readable to the world
chmod 0600 ssh_key
# Start the SSH authentication agent
eval `ssh-agent -s`
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
    echo -e "\n${YELLOW}${BOLD}Building HTML for $DCFILE ...${NC}\n"
    $DAPS_SR -d $DCFILE html --draft
    echo -e "\n${YELLOW}${BOLD}Building single HTML for $DCFILE ...${NC}\n"
    $DAPS_SR -d $DCFILE html --single --draft
    wait
done

# Now clone the GitHub pages repository, checkout the gh-pages branch and clean files
mkdir ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts
echo -e "${YELLOW}${BOLD}Cloning GitHub pages repository${NC}\n"
git clone ssh://git@github.com/SUSEdoc/$REPO.git /tmp/$REPO
git -C /tmp/$REPO/ checkout gh-pages
rm -r /tmp/$REPO/$PRODUCT

# Copy the HTML and single HTML files for each DC file
for DCFILE in $DCBUILDLIST; do
    MVFOLDER=$(echo $DCFILE | sed -e 's/DC-//g')
    echo -e "${YELLOW}${BOLD}Moving $DCFILE...${NC}\n"
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
