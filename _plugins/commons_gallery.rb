require 'net/http'
require 'json'
require 'fileutils'
require 'time'
require 'uri'
require 'cgi'

module Jekyll
  class CommonsGalleryGenerator < Generator
    safe true
    priority :low

    CACHE_DIR = '_data/commons_cache'
    CACHE_TTL = 7 * 24 * 60 * 60
    OLD_EVENT_THRESHOLD = 365 * 24 * 60 * 60

    def generate(site)
      @site = site
      @cache_dir = File.join(site.source, CACHE_DIR)
      FileUtils.mkdir_p(@cache_dir)

      @skip_update = ENV.key?('JEKYLL_SKIP_GALLERY_UPDATE')
      @metadata = load_metadata

      if @skip_update
        Jekyll.logger.info "CommonsGallery:", "Skipping API updates (JEKYLL_SKIP_GALLERY_UPDATE set)"
      end

      site.pages.each do |page|
        category = page.data['commons_category']
        next if category.nil? || category.to_s.strip.empty?

        category_key = category.to_s.strip.gsub(' ', '_')
        gallery_html, last_fetched = resolve_gallery(page, category_key)
        page.data['commons_gallery_html'] = gallery_html
        page.data['commons_gallery_last_fetched'] = last_fetched
      end

      save_metadata
    end

    private

    def resolve_gallery(page, category_key)
      cached_html = read_cached_html(category_key)
      last_fetched = @metadata.dig('categories', category_key, 'last_fetched')

      if @skip_update
        return [cached_html, last_fetched]
      end

      if should_skip_api?(page, category_key, last_fetched)
        Jekyll.logger.info "CommonsGallery:", "Skipping #{category_key} (old event, cache fresh)"
        return [cached_html, last_fetched]
      end

      gallery_html = fetch_gallery(category_key)
      if gallery_html == :empty
        last_fetched = Time.now.iso8601
        write_cached_html(category_key, '')
        update_metadata(category_key, { 'last_fetched' => last_fetched, 'last_attempted' => last_fetched })
        Jekyll.logger.info "CommonsGallery:", "Category #{category_key} is empty"
        return [nil, last_fetched]
      elsif gallery_html == :api_error
        if last_fetched
          Jekyll.logger.warn "CommonsGallery:", "API error for #{category_key}, using cache from #{last_fetched}"
        else
          update_metadata(category_key, { 'last_fetched' => nil, 'last_attempted' => Time.now.iso8601 })
          Jekyll.logger.warn "CommonsGallery:", "API error for #{category_key}, no cache available"
        end
        return [cached_html, last_fetched]
      elsif gallery_html
        last_fetched = Time.now.iso8601
        write_cached_html(category_key, gallery_html)
        update_metadata(category_key, { 'last_fetched' => last_fetched, 'last_attempted' => last_fetched })
        Jekyll.logger.info "CommonsGallery:", "Fetched #{category_key} from API"
        return [gallery_html, last_fetched]
      else
        Jekyll.logger.warn "CommonsGallery:", "Unexpected nil from fetch_gallery for #{category_key}"
        [cached_html, last_fetched]
      end
    end

    def should_skip_api?(page, category_key, last_fetched_str)
      start_time = page.data['start_time']
      return false unless start_time

      event_time = begin
        Time.parse(start_time.to_s)
      rescue ArgumentError
        nil
      end
      return false unless event_time

      event_age = Time.now - event_time
      return false if event_age < OLD_EVENT_THRESHOLD

      if last_fetched_str
        last_fetched = begin
          Time.parse(last_fetched_str)
        rescue
          nil
        end
        if last_fetched && (Time.now - last_fetched) < CACHE_TTL
          return true
        end
      end

      last_attempted_str = @metadata.dig('categories', category_key, 'last_attempted')
      if last_attempted_str
        last_attempted = begin
          Time.parse(last_attempted_str)
        rescue
          nil
        end
        if last_attempted && (Time.now - last_attempted) < 86400
          return true
        end
      end

      false
    end

    def load_metadata
      path = File.join(@cache_dir, '_metadata.json')
      if File.exist?(path)
        JSON.parse(File.read(path))
      else
        { 'categories' => {} }
      end
    rescue
      { 'categories' => {} }
    end

    def save_metadata
      path = File.join(@cache_dir, '_metadata.json')
      File.write(path, JSON.pretty_generate(@metadata) + "\n")
    end

    def read_cached_html(category_key)
      path = File.join(@cache_dir, "#{category_key}.html")
      File.exist?(path) ? File.read(path) : nil
    end

    def write_cached_html(category_key, html)
      path = File.join(@cache_dir, "#{category_key}.html")
      File.write(path, html)
    end

    def update_metadata(category_key, fields)
      @metadata['categories'] ||= {}
      @metadata['categories'][category_key] ||= {}
      @metadata['categories'][category_key].merge!(fields)
    end

    def fetch_gallery(category)
      result = api_call(
        'action' => 'query',
        'prop' => 'imageinfo',
        'generator' => 'categorymembers',
        'iiprop' => 'url|metadata',
        'iiurlwidth' => '255',
        'gcmtitle' => "Category:#{category}",
        'gcmlimit' => '50',
        'gcmtype' => 'file'
      )
      if result.nil? || !result.is_a?(Hash)
        return :api_error
      end
      pages = result.dig('query', 'pages')
      return :empty if pages.nil? || pages.empty?

      labels = fetch_entity_labels(pages)
      return :api_error if labels.nil?

      photos = build_photos(pages, labels, category)
      return :empty if photos.empty?

      photos.sort_by! { |p| p[:time] }
      photos.map { |p| render_photo(p) }.join("\n")
    rescue => e
      Jekyll.logger.warn "CommonsGallery:", "Failed to fetch gallery for #{category}: #{e.message}"
      :api_error
    end

    def fetch_entity_labels(pages)
      media_ids = pages.map { |p| "M#{p['pageid']}" }.join('|')
      result = api_call(
        'action' => 'wbgetentities',
        'ids' => media_ids
      )
      return nil if result.nil? || result['entities'].nil?
      result['entities']
    end

    @@last_api_call = Time.at(0)

    def api_call(params)
      elapsed = Time.now - @@last_api_call
      sleep(0.3 - elapsed) if elapsed < 0.3
      uri = URI('https://commons.wikimedia.org/w/api.php')
      uri.query = URI.encode_www_form(params.merge('format' => 'json', 'formatversion' => '2'))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 15
      http.open_timeout = 10
      response = http.get(uri.request_uri, 'User-Agent' => 'GeogeeksJekyll/1.0 (https://geogeeks.org)')
      @@last_api_call = Time.now
      JSON.parse(response.body)
    rescue => e
      Jekyll.logger.warn "CommonsGallery:", "API call failed: #{e.message}"
      nil
    end

    def build_photos(pages, entities, category)
      photos = []
      pages.each do |page|
        next if page['imageinfo'].nil? || page['imageinfo'].empty?

        info = page['imageinfo'][0]
        next if info['thumburl'].nil?

        time = ''
        (info['metadata'] || []).each do |meta|
          if meta['name'] == 'DateTimeOriginal'
            time = meta['value'][11, 5] || ''
            break
          end
        end

        caption = begin
          entities.dig("M#{page['pageid']}", 'labels', 'en', 'value') || '[No caption; please add one!]'
        rescue
          '[No caption; please add one!]'
        end

        encoded_title = CGI.escape(page['title'].to_s).gsub('+', '%20')
        photos << {
          page_title: page['title'],
          url: "https://commons.wikimedia.org/wiki/Category:#{category}#/media/#{encoded_title}",
          thumburl: info['thumburl'],
          thumbheight: info['thumbheight'].to_i,
          thumbwidth: info['thumbwidth'].to_i,
          time: time,
          caption: caption
        }
      end
      photos
    end

    def render_photo(p)
      colspan = p[:thumbheight] > p[:thumbwidth] ? '2' : '3'
      %(<a class="figure col-md-#{colspan} gallery-item gallery-item-cached" href="#{h(p[:url])}">
        <figure>
          <img src="#{h(p[:thumburl])}" class="figure-img img-fluid rounded" loading="lazy" alt="#{h(p[:caption])}">
          <figcaption><strong>#{p[:time]}: </strong>#{h(p[:caption])}</figcaption>
        </figure>
      </a>).gsub(/\n\s*/, '')
    end

    def h(text)
      text.to_s
        .gsub('&', '&amp;')
        .gsub('<', '&lt;')
        .gsub('>', '&gt;')
        .gsub('"', '&quot;')
    end
  end
end
