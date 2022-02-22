#!/usr/bin/env bash

contents=($(ls -A files/))

cat /dev/null > files/contents

for file in "${contents[@]}"; do
  if [ $file != "contents" ]; then
    echo $file >> files/contents
  fi
done
