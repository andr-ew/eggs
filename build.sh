#!/bin/bash

mkdir build
cd ..
zip -r eggs/build/complete-source-code.zip eggs/ -x "eggs/.git/*" "eggs/lib/doc/*" "eggs/build.sh" "eggs/build/*"
