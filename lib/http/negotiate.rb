require "http/negotiate/version"

# We are basically copying Gisle Aas' (Perl) HTTP::Negotiate here,
# with Ruby characteristics.
module HTTP::Negotiate
  private

  HEADERS = { type: '' }.merge(
    %i[charset language encoding].map { |k| [k, ?_ + k.to_s.upcase] }.to_h)

  # these are for the hash representation of variant metadata
  KEYS = %i[weight type encoding charset language size].freeze

  public

  # Return a parsed representation of the relevant header
  # set. Translates `Accept-*` (`HTTP_ACCEPT_*`) into lower-case
  # symbols, so `Accept-Language` or `HTTP_ACCEPT_LANGUAGE` becomes
  # `:language`. Same for `:charset`, and `:encoding`, etc., save for
  # plain `Accept` which is translated to `:type`. The parameter
  # `:add_langs` will supplement `Accept-Language` assertions of
  # specific languages with their more generic counterparts, if not
  # already present in the header, with a slightly lower quality
  # score, e.g. `en-us` adds `en;q=0.999`, `zh-cn;q=0.8` adds
  # `zh;q=0.799`.
  #
  # @param request [Hash, Rack::Request, #env] Anything roughly a hash
  #  of headers
  # @param add_langs [false, true] whether to supplement language tags
  #
  # @return [Hash] the parsed `Accept*` headers
  #
  def parse_headers request, add_langs: false
    # pull accept headers
    request = request.env if request.respond_to? :env

    # no-op if this is already parsed
    return request if request.is_a? Hash and
      request.all? { |k, v| k.is_a? Symbol and v.is_a? Hash }

    # this will ensure that the keys will match irrespective of
    # whether it's passed in as actual http headers or a cgi-like env
    request = request.transform_keys do |k|
      k = k.to_s.strip
      /^Accept(-.*)?$/i.match?(k) ? "HTTP_#{k.upcase.tr ?-, ?_}" : k
    end

    # the working set
    accept = {}

    HEADERS.each do |k, h|
      if hdr = request["HTTP_ACCEPT#{h}"]
        defq = 1.0
        # strip out all the whitespace from the header value;
        # theoretically you can have quoted-string parameter values
        # but we don't care (although interestingly according to rfc7231,
        # accept-language only affords q= and not arbitrary parameters)
        hdr = hdr.dup.gsub(/\s+/, '')

        # don't add the test group if it's an empty string, because
        # postel's law is a thing
        next if hdr.empty?

        accept[k] = hdr.split(/,+/).map do |c|
          val, *params = c.split(/;+/)
          params = params.map do |p|
            k, v = p.split(/=+/, 2)
            k = k.downcase.to_sym
            v = v.to_f if v and k == :q
            [k, v]
          end.to_h
          if params[:q]
            params[:q] = 1.0 if params[:q] > 1.0
            params[:q] = 0.0 if params[:q] < 0.0
          else
            params[:q] = defq
            defq -= 0.0001
          end
          # none of the accept header contents are case sensitive
          [val.downcase, params]
        end.to_h
      end
    end

    # sneakily supplant shorter language tags at 99% q
    if accept[:language]
      langs = accept[:language]
      langs.transform_keys! { |k| k.tr(?_, ?-).tr_s(?-, ?-).downcase }
      if add_langs
        langs.keys.select { |k| k.include? ?- }.each do |k|
          # a tag with q=0 has to be explicitly set in the header
          next if (q = langs[k][:q]) == 0
          lang = k.split ?-
          (1..lang.length).to_a.reverse.each do |i|
            # each shorter language tag will have a slightly lower score
            langs[lang.slice(0, i).join ?-] ||= { q: q *= 0.999 }
          end
        end
      end
    end

    accept
  end

  # The variant mapping takes the following form:
  # { variant => [weight, type, encoding, charset, language, size] }
  #
  # (Alternatively this array can be a hash with the same keys as symbols.)
  #
  # * the variant can be anything, including the actual variant
  # * the weight is a number between 0 and 1 denoting the initial
  #   preference for the variant
  # * type, encoding, charset, language are all strings containing
  #   their respective standardized tokens (note "encoding" is like
  #   `gzip`, not like `utf-8`: that's "charset")
  # * size is the number of bytes, an integer
  #
  # Returns either the winning variant or all variants if requested,
  # sorted by the algorithm, or nil or the empty array if none are
  # selected.
  #
  # @param request [Hash,Rack::Request,#env] Anything roughly a hash of headers
  # @param variants [Hash] the variants, described above
  # @param add_langs [false, true] whether to supplement language tags
  # @param all [false, true] whether to return a sorted list or not
  # @param cmp [Proc] a secondary comparison of variants as a tiebreaker
  #
  def negotiate request, variants, add_langs: false, all: false, cmp: nil
    accept = parse_headers request, add_langs: add_langs

    # convert variants to array
    variants = variants.transform_values do |v|
      v.is_a?(Hash) ? v.values_at(*KEYS) : v
    end

    # check if any of the variants specify a language, since this will
    # affect the scoring
    any_lang = variants.values.any? { |v| v[4] }

    # chosen will be { variant => value }
    scores = {}
    variants.keys.each do |var|
      qs, type, encoding, charset, language, size = variants[var]
      # some defaults
      qs   ||= 1
      type ||= ''
      size ||= 0

      # coerce encoding
      encoding = encoding.to_s.strip.downcase if encoding
      # coerce charset
      charset = charset.to_s.strip.downcase if charset
      # coerce language to canonical form
      language = language.to_s.strip.downcase.tr_s '_-', '-' if language

      # calculate encoding quality
      qe = 1
      if accept[:encoding] and encoding
        qe = 0
        qe = accept[:encoding][encoding][:q] if accept[:encoding][encoding]
        qe = accept[:encoding][?*][:q] if accept[:encoding][?*] and
          accept[:encoding][?*][:q] > qe
      end

      # calculate charset quality
      qc = 1
      if accept[:charset] and charset and charset != 'us-ascii'
        qc = 0
        qc = accept[:charset][charset][:q] if accept[:charset][charset]
        qc = accept[:charset][?*][:q] if accept[:charset][?*] and
          accept[:charset][?*][:q] > qc
      end

      # calculate the language quality
      ql = 1
      if accept[:language]
        if language
          ql = 0.001 # initial value is very low but not zero
          lang = language.split(/-+/)
          (0..lang.length).to_a.reverse.each do |i|
            # apparently there is no wildcard for accept-language? no
            # wait there is: rfc4647 $2.1 via rfc7231 $5.3.5
            test = i > 0 ? lang.slice(0, i).join(?-) : ?*
            if accept[:language][test]
              al = accept[:language][test][:q]
              # *;q=0 will override
              if al == 0 and test != ?*
                ql = 0
                break
              elsif al > ql
                ql = al
              end
            end
          end
        elsif any_lang
          # XXX not sure if language-less variants in the same pool
          # with language-y ones
          ql = 0.5
        end
      end

      # calculate the type quality
      qt = 1
      if accept[:type] and type
        type = type.to_s
        qt = 0
        at = {}
        accept[:type].each do |k, v|
          maj, min = k.split(/\//)
          x = at[maj] ||= {}
          x[min] = v
        end

        # XXX we do not actually try to do the params this time
        mt, *params = type.split(/;+/)
        maj, min    = mt.split(/\/+/)
        params = params.map { |p| p.split(/=+/, 2) }

        # warn maj.inspect, min.inspect

        # XXX match params at some point
        qt = if at.fetch(maj, {})[min]
               at[maj][min][:q]
             elsif at.fetch(maj, {})[?*]
               at[maj][?*][:q]
             elsif at.fetch(?*, {})[?*]
               at[?*][?*][:q]
             else
               0.1
             end

      end

      scores[var] = [qs * qe * qc * ql * qt, size]
    end

    # XXX do something smarter here for secondary comparison
    cmp ||= -> a, b { 0 }

    chosen = scores.sort do |a, b|
      c = b.last.first <=> a.last.first        # first compare scores
      c = cmp.call(a.first, b.first) if c == 0 # then secondary cmp
      c == 0 ? a.last.last <=> b.last.last : c # then finally by size
    end.map(&:first)

    all ? chosen : chosen.first
  end

  extend self
end
