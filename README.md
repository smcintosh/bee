# Bee

Build Execution Explorer (BEE) is a tool for interactively exploring data produced during a build.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bee'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install bee

## Usage

To run the GDF importing tool, simply execut 

```shell
$ bin/gdf_importer <GDF_file>
```

Options and configuration are still under development. Currently, an embedded Neo4j instance is created in the directory that the tool is executed in with the name .beedb.

## Development

You need to have JRuby installed. After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/smcintosh/bee.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

