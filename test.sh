#!/bin/bash

read -r -p "Install Homebrew? [y/N] " input

case $input in
      [yY][eE][sS]|[yY])
            echo "You say Yes"
            ;;
      [nN][oO]|[nN])
            echo "You say No"
            ;;
      *)
            echo "You say No (nothing)"
            exit 1
            ;;
esac