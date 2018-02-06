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

mkdir -p /root/.config/daps/
echo DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc" > /root/.config/daps/dapsrc

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

for DCFILE in $DCLIST; do
    echo -e "\n${YELLOW}${BOLD}Validating $DCFILE (with $(rpm -qv geekodoc))...${NC}\n"
    daps -vv -d $DCFILE validate || exit 1
    echo -e "\n${YELLOW}${BOLD}Checking for missing images in $DCFILE ...${NC}\n"
    MISSING_IMAGES=$(daps -d $DCFILE list-images-missing)
    if [ -n "$MISSING_IMAGES" ]; then
        echo -e "\n${RED}${BOLD}Missing images:${NC}"
        echo -e "$MISSING_IMAGES"
        exit 1
    else
        echo -e "\n${GREEN}All images available.${NC}\n"
    fi
    wait
done
