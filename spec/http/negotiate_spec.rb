RSpec.describe HTTP::Negotiate do
  it "has a version number" do
    expect(HTTP::Negotiate::VERSION).not_to be nil
  end

  it 'correctly negotiates some variants' do
    headers  = { Accept: 'text/html, */*;q=0', "Accept-Language": 'en-us, *;q=0' }
    variants = {
      lol:  [0.5, 'text/html',       nil, 'iso-8859-1',  'en', 31337],
      wut:  [1.0, 'application/xml', nil, 'utf-8',       'en', 12345],
      hurr: [0.1, 'text/plain'                                      ],
      good: [0.5, 'text/html',       nil, 'utf-8',       'en', 22222],
    }
    # XXX you know, do some actual tests
    chosen = HTTP::Negotiate.negotiate headers, variants, add_langs: true
    expect(chosen).to eql :good
  end
end
