#!/bin/bash
set -e

bundle exec jekyll build
bundle exec htmlproofer ./_site --only-4xx --check-favicon --check-html
