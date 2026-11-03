# frozen_string_literal: true

require "spec_helper"
require "yeptris"

# Every schema in the vendored JSON-Schema-Test-Suite subset must validate
# against its dialect meta-schema — this keeps the offline meta-schema
# corpus honest against the official conformance corpus.
RSpec.describe "JSON-Schema-Test-Suite corpus" do
  # rubocop:disable Naming/VariableNumber -- keys mirror dialect names
  def corpus
    {
      draft2020_12: "draft2020-12",
      draft7: "draft7",
    }
  end
  # rubocop:enable Naming/VariableNumber

  def corpus_files(dir)
    Dir[File.join(__dir__, "..", "fixtures", "jsts", dir, "*.json")]
  end

  it "vendors the expected corpus" do
    expect(corpus_files("draft2020-12").length).to eq(5)
    expect(corpus_files("draft7").length).to eq(3)
  end

  it "validates every suite schema against its meta-schema" do
    failures = []

    corpus.each do |dialect, dir|
      corpus_files(dir).each do |path|
        cases = Yeptris::JSON.load(File.read(path))
        cases.each do |test_case|
          errors = Lutaml::Jsonschema::Validator.validate(
            test_case["schema"], dialect
          )
          next if errors.nil? || errors.empty?

          failures << "#{File.basename(path)}: #{test_case['description']}: " \
                      "#{errors.map(&:message).join('; ')}"
        end
      end
    end

    expect(failures).to be_empty
  end
end
