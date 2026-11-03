# frozen_string_literal: true

# `rake verify:remarks` — the remark conservation gate. Runs only the
# production-scale checks (`:production_scale` tag; see spec_helper's
# filter), which the default suite excludes: they parse a full-size
# schema and cost about a minute.
#
# Guarded: rake-compiler-dock's bundle carries production dependencies
# only, and cross-gem rake invocations must still load the task files.
if defined?(RSpec)
  RSpec::Core::RakeTask.new(:"verify:remarks") do |task|
    task.rspec_opts = "--tag production_scale"
  end
else
  warn "verify_remarks: rspec not available — task not defined"
end
