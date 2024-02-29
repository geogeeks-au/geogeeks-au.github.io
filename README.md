# Geogeeks Public Website

This is the source code for the [Geogeeks](https://geogeeks.org/) public website.

## Getting Started

1. Install [Jekyll](https://jekyllrb.com/) and dependencies:
   * Install [prereqs for Jekyll](https://jekyllrb.com/docs/installation/):
    ```bash
    sudo apt-get install ruby
    ```
   * Install Jekyll and bundler:
    ```bash
    sudo gem install jekyll bundler
    ```
2. Clone this repository, and `cd` into it.
3. Install project dependencies:
    ```bash
    bundle config set --local path 'vendor/bundle'
    bundle install
    ```
4. Start the dev server on [http://localhost:4000](http://localhost:4000) with:
    ```bash
    bundle exec jekyll serve
    ```

## Adding a new event

Event pages should use the `event` layout, with a structure like the following:

```
---
layout: event
title: "Event: Title Here"
start_time: 2023-11-12 17:30
end_time: 2023-11-12 20:00
location:
    name: 
    address: 
    latitude: 
    longitude: 
registration_url: 
commons_category: "Cat name without 'Category:' prefix"
homepage: true
---
Then describe the event here, in Markdown.

```

## Other sites

Other places to keep up to date with our info:

* [OSM Community Index](https://github.com/osmlab/osm-community-index/blob/main/resources/oceania/australia/geogeeks_perth.json)
* [Twitter](https://twitter.com/geogeeks_au)
