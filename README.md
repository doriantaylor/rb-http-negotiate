# HTTP::Negotiate

This is literally just a port of Gisle Aas's
[HTTP::Negotiate](https://metacpan.org/pod/HTTP::Negotiate) written in
Perl, with a couple tiny changes to the interface. The `negotiate`
method is accessible as either a class method or instance method, so
you can take your pick of interface.

## Usage

```ruby
require 'http/negotiate'

# access it as an ordinary function
HTTP::Negotiate.negotiate request, variants

# ...or include it as an instance method
class Foo
  include HTTP::Negotiate
  
  # you now have access to #negotiate
end

```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'http-negotiate'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install http-negotiate


## Contributing

Bug reports and pull requests are welcome at
[the Github repository](https://github.com/doriantaylor/rb-http-negotiate).

## Copyright & License

©2020 [Dorian Taylor](https://doriantaylor.com/)

This software is provided under
the [Apache License, 2.0](https://www.apache.org/licenses/LICENSE-2.0).
