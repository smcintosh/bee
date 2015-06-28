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

## Configuration 

We use [YAML](http://yaml.org/) configuration files to configure the importer command. An example configuration file can be found in `bin/config.yml`.

## Usage

To run the importing tool, simply execute

```shell
$ bin/importer <YAML_file>
```

Options and configuration are still under development. Currently, an embedded Neo4j instance is created under the `.beedb` in the current directory. A different path can be specified using the `beedb` configuration parameter in the YAML file.

## Development

You need to have JRuby installed. After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/smcintosh/bee.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

