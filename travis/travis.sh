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

mkdir -p /root/.config/daps/
echo DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc" > /root/.config/daps/dapsrc 
DCLIST=$(ls DC-*-all)
if [ -z "$DCLIST" ] ; then
    DCLIST=$(ls DC-*)
fi
for DCFILE in $DCLIST; do 
    echo -e "\n${YELLOW}${BOLD}Validating XML of $DCFILE ... ${NC}\n" 
    daps -vv -d $DCFILE validate || exit 1 
    echo -e "\n${YELLOW}${BOLD}Validating images of $DCFILE ... ${NC}\n" 
    MISSING_IMAGES=$(daps -d $DCFILE list-images-missing)
    if [ -n "$MISSING_IMAGES" ]; then
        echo -e "\n${RED}${BOLD}Missing images: ${NC}\n" 
        echo -e "$MISSING_IMAGES"
        exit 1
    else
        echo -e "\n${RED}${BOLD}No image missing. ${NC}\n" 
    fi
    wait
done
