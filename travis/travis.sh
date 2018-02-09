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

DCCONF=".travis-check-docs"

# Setting --styleroot makes sure that DAPS does not error out when the
# stylesheets requested by the DC file are not available in the container.
DAPS_SR="daps --styleroot /usr/share/xml/docbook/stylesheet/suse2013-ns/"

mkdir -p /root/.config/daps/
echo DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc" > /root/.config/daps/dapsrc

source env.list
echo "Repo: $TRAVIS_REPO_SLUG"
echo "Source branch: $SOURCE_BRANCH"
echo "Target branch: $TARGET_BRANCH"
echo "Pull request: $TRAVIS_PULL_REQUEST"

if [ $LIST_PACKAGES -eq "1" ] ; then
  rpm -qa | sort
fi

DCLIST=$(ls DC-*-all)
if [[ -f "$DCCONF" ]]; then
    DCLIST=$(cat "$DCCONF")
elif [ -z "$DCLIST" ] ; then
    DCLIST=$(ls DC-*)
fi

# Do this first, so this fails as quickly as possible.
unavailable=
for DCFILE in $DCLIST; do
    [[ ! -f $DCFILE ]] && unavailable+="$DCFILE "
done
if [[ ! -z $unavailable ]]; then
    echo "${RED}${BOLD}The following DC file(s) is/are configured in $DCCONF but not present in repository:${NC}"
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

if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo -e "${YELLOW}${BOLD}Only validating, not building. Current branch: $TRAVIS_BRANCH${NC}\n"
    exit 0
fi

echo -e "${YELLOW}${BOLD}Building${NC}\n"
for DCFILE in $DCLIST; do
    echo -e "${YELLOW}${BOLD}Building $DCFILE (with $(rpm -qv geekodoc))...${NC}\n"
    $DAPS_SR -vv -d $DCFILE html
    $DAPS_SR -vv -d $DCFILE html --single
    echo -e '\n\n\n'
    wait
done

echo -e "${YELLOW}${BOLD}Cloning GitHub pages repository${NC}\n"
REPO=$(echo $TRAVIS_REPO_SLUG | sed -e 's/.*\///g')
git clone https://git@github.com/SUSEdoc/$REPO.git
