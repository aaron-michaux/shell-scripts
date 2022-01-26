#!/bin/bash

while true; do
    read -p "Is git synchronized correctly?" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

kb exec make style_fix

