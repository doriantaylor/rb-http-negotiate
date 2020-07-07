RSpec.describe HTTP::Negotiate do
  it "has a version number" do
    expect(HTTP::Negotiate::VERSION).not_to be nil
  end

  it 'correctly negotiates some variants' do
    headers  = { Accept: 'text/html, */*;q=0' }
    variants = {
      lol: [1, 'text/html', nil, 'iso-8859-1', 'en', 31337],
      wut: [1, 'application/xml', nil, 'utf-8', 'en', 12345],
    }
    chosen = HTTP::Negotiate.negotiate headers, variants
    expect(chosen).to eql :lol
  end
end
