require "http/negotiate/version"

# We are basically copying Gisle Aas' (Perl) HTTP::Negotiate here,
# with Ruby characteristics.
module HTTP::Negotiate
  private

  HEADERS = { type: '' }.merge(
    %i[charset language encoding].map { |k| [k, ?_ + k.to_s.upcase] }.to_h)

  public

  # The variant mapping takes the following form:
  # { variant => [weight, type, encoding, charset, language, size] }
  #
  # * the variant can be anything, including the actual variant
  # * the weight is a number between 0 and 1 denoting the initial
  #   preference for the variant
  # * type, encoding, charset, language are all strings containing
  #   their respective standardized tokens (note "encoding" is like
  #   `gzip`, not like `utf-8`: that's "charset")
  # * size is the number of bytes
  #
  # Returns either the winning variant or all variants if requested,
  # sorted by the algorithm, or nil or the empty array if none are
  # selected.
  #
  # @param request [Hash,Rack::Request,#env] Anything roughly a hash of headers
  # @param variants [Hash] the variants, described above
  # @param all [false, true] whether to return 
  #
  def negotiate request, variants, all: false
    # pull accept headers
    request = request.env if request.respond_to? :env
    # this will ensure that the keys will match irrespective of
    # whether it's passed in as actual http headers or a cgi-like env
    request = request.transform_keys do |k|
      if /^Accept(-.+)?$/i.match? k.to_s
        'HTTP_' + k.to_s.upcase.tr(?-, ?_)
      else
        k
      end
    end

    # the working set
    accept = {}

    HEADERS.each do |k, h|
      if hdr = request["HTTP_ACCEPT#{h}"]
        defq = 1.0
        # theoretically you can have quoted-string parameters but we don't care
        hdr = hdr.dup.gsub(/\s+/, '')
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

    # check if any of the variants specify a language, since this will
    # affect the scoring
    any_lang = variants.values.any? { |v| v[5] }

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
      if accept[:language] and language
        ql = 0.001 # initial value is very low but not zero
        lang = language.split(/-+/)
        (1..lang.length).to_a.reverse.each do |i|
          test = lang.slice(0, i).join ?-
          if accept[:language][test]
            al = accept[:language][test][:q]
            if al == 0
              ql = 0
              break
            elsif al > ql
              ql = al
            end
          end
        end
        # apparently there is no wildcard for accept-language?
      elsif accept[:language] and any_lang
        ql = 0.5
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
        if at[maj]
          if at[maj][min]
            qt = at[maj][min][:q]
          elsif at[maj][?*]
            qt = at[maj][?*][:q]
          else
            qt = 0.1
          end
        elsif at[?*]
          # ???
          qt = at[?*].fetch(?*, { q: 0.1 })[:q]
        else
          # ???
          qt = 0.1
        end

      end

      scores[var] = qs * qe * qc * ql * qt
    end

    chosen = scores.sort { |a, b| b.last <=> a.last }.map(&:first)
    all ? chosen : chosen.first
  end

  extend self
end

