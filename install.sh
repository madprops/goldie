#!/usr/bin/env bash
nim compile -d:release -o=bin/goldie-release-linux src/goldie.nim
mv bin/goldie-release-linux ~/bin/goldie