# Geogeeks Public Website

This is the source code for the [Geogeeks](https://geogeeks.org/) public website.

## Getting Started

1. Install [Jekyll](https://jekyllrb.com/) and dependencies:
    * Install [prereqs for Jekyll](https://jekyllrb.com/docs/installation/).
    * Install Jekyll and bundler:
        ```bash
        gem install jekyll bundler
        ```
2. Clone this repository, and `cd` into it.
3. Install project dependencies:
    ```bash
    bundle install
    ```
* Start the dev server on [http://localhost:4000](http://localhost:4000) with:
    ```bash
    bundle exec jekyll serve
    ```

## Adding a new event

Event pages should use the `event` layout, with a structure like the following:

```
---
layout: event
title: "Event: Title Here"
date:
time:
location:
    name: 
    address: 
    latitude: 
    longitude: 
    geojson: filename-here.geojson
registration_url:
homepage: true
---
Then describe the event here, in Markdown.

```
