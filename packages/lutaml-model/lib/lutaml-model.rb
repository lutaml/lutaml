# frozen_string_literal: true

# Transitional alias (lutaml/lutaml#233): the lutaml-model runtime lives in
# the `lutaml` gem. `require "lutaml-model"` and `require "lutaml/model"`
# keep working; this entry point prints one deprecation notice per process.
require "lutaml/model"
require_relative "lutaml_model_shim/deprecation"

LutamlModelShim::Deprecation.warn_once
