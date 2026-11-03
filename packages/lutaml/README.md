# LutaML

LutaML is data models in textual form. The `lutaml` gem is the umbrella
of the LutaML family: it installs the core engine together with the
textual modelling languages built on top of it. It is domain-neutral:
EXPRESS lives in [expressir](https://github.com/lutaml/expressir), not here.

## The LutaML family

| Gem | Role |
| --- | --- |
| [lutaml-model](https://github.com/lutaml/lutaml-model) | Core declarative data modelling engine with serialization to and from XML, JSON, YAML, TOML and Hash. |
| [lutaml-lml](https://github.com/lutaml/lutaml-lml) | Parser and converter for the LutaML Model Language (LML, `.lml`/`.lutaml`) textual syntax. |
| [lutaml-uml](https://github.com/lutaml/lutaml-uml) | UML domain models, document repository (`.lur` packages), and static-site generation. |
| [expressir](https://github.com/lutaml/expressir) | EXPRESS front: language parser and repository tooling (standalone, not a `lutaml` dependency). |
| **lutaml** (this gem) | Umbrella for the family (LML front and model runtime). |

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

document = Lutaml::Lml.parse_document(File.new("model.lutaml"))
```

Requiring `lutaml` loads `lutaml-lml`, `lutaml-uml` (including its
repository layer); every member of the
family builds on `lutaml-model`.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
