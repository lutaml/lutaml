# LutaML

LutaML is data models in textual form. The `lutaml` gem is the umbrella
of the LutaML family: it installs the core engine together with the
textual modelling languages built on top of it, and exposes the EXPRESS
parsing surface under the `Lutaml::Express` namespace.

## The LutaML family

| Gem | Role |
| --- | --- |
| [lutaml-model](https://github.com/lutaml/lutaml-model) | Core declarative data modelling engine with serialization to and from XML, JSON, YAML, TOML and Hash. |
| [lutaml-lml](https://github.com/lutaml/lutaml-lml) | Parser and converter for the LutaML Model Language (LML, `.lml`/`.lutaml`) textual syntax. |
| [lutaml-uml](https://github.com/lutaml/lutaml-uml) | UML domain models, document repository (`.lur` packages), and static-site generation. |
| [expressir](https://github.com/lutaml/expressir) | EXPRESS language parser and repository tooling. |
| **lutaml** (this gem) | Umbrella for the family; EXPRESS schema parsing through `Lutaml::Express::Parsers::Exp`. |

The wider ecosystem installs separately as needed:
[lutaml-store](https://github.com/lutaml/lutaml-store) (document store),
[lutaml-hal](https://github.com/lutaml/lutaml-hal) (HAL documents),
[lutaml-jsonschema](https://github.com/lutaml/lutaml-jsonschema) (JSON
Schema generation), [lutaml-xmi](https://github.com/lutaml/lutaml-xmi)
(XMI import), and [lutaml-path](https://github.com/lutaml/lutaml-path)
(path queries over LutaML models).

## Installation

```ruby
gem "lutaml"
```

## Usage

```ruby
require "lutaml"

repository = File.open("schema.exp") do |io|
  Lutaml::Express::Parsers::Exp.parse(io)
end
```

Requiring `lutaml` loads `lutaml-lml`, `lutaml-uml` (including its
repository layer) and the EXPRESS parser autoload; every member of the
family builds on `lutaml-model`.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
