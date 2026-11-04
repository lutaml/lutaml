# frozen_string_literal: true

namespace :verify do
  desc "Check remarks against the recorded round-trip gaps, production included"
  task :remarks do
    specs = %w[
      spec/expressir/remark_conservation_spec.rb
      spec/expressir/remark_ownership_spec.rb
      spec/expressir/express/formatter_remark_conservation_spec.rb
      spec/expressir/express/formatter_remark_ownership_spec.rb
    ]

    sh({ "EXPRESSIR_PRODUCTION_SCALE" => "1" },
       "bundle", "exec", "rspec", *specs)
  end
end
