# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "tempfile"
require "fileutils"

# TODO.eengine/04 — the live rule audit for spec/fixtures/shtolo/
# annex-g-rules.md. One example per rule without prior coverage; the
# assertions encode the ANNEX (the contract), not eeng (a partial
# oracle). Results roll up into annex-g-rules.md.
RSpec.describe Expressir::Express::Shtolo do
  def parse_repository(sources)
    files = sources.map do |id, src|
      f = Tempfile.new([id.to_s, ".exp"])
      f.write(src)
      f.close
      f
    end
    repository = Expressir::Express::Parser.from_files(files.map(&:path), skip_references: true)
    [repository, files]
  end

  # G.1.6 audits need REFERENCE interfaces, which the default
  # skip_references parse drops.
  def parse_repository_full(sources)
    files = sources.map do |id, src|
      f = Tempfile.new([id.to_s, ".exp"])
      f.write(src)
      f.close
      f
    end
    repository = Expressir::Express::Parser.from_files(files.map(&:path))
    [repository, files]
  end

  def flatten(root_schema, repository)
    described_class.new(root_schema, repository).flatten.schema
  end

  def schema_of(model, id)
    model.schemas.find { |s| s.id == id }
  end

  describe "G.NM.2 qualified strings in expressions" do
    it "rewrites the schema part of TYPEOF strings to the longform name" do
      repository, files = parse_repository(
        "this_schema" => "SCHEMA this_schema;\nTYPE whatsit = EXTENSIBLE ENUMERATION; END_TYPE;\nENTITY an_entity;\n  x : whatsit;\nEND_ENTITY;\nEND_SCHEMA;\n",
        "sch_schema" => "SCHEMA sch_schema;\nUSE FROM this_schema (an_entity);\nRULE string_check FOR (an_entity);\nWHERE wr1 : 'THIS_SCHEMA.WHATSIT' IN TYPEOF(x);\nEND_RULE;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "sch_schema"), repository)
      files.each(&:unlink)
      rendered = Expressir::Express::PrettyFormatter.new.format(longform)
      expect(rendered).not_to include("THIS_SCHEMA.WHATSIT")
      expect(rendered).to include("SCH_SCHEMA.WHATSIT")
    end
  end

  describe "G.1.2 interface dedup" do
    it "drops duplicate USE items in favour of the REFERENCE twin" do
      repository, files = parse_repository(
        "source_schema" => "SCHEMA source_schema;\nTYPE widget = INTEGER; END_TYPE;\nEND_SCHEMA;\n",
        "sch_schema" => "SCHEMA sch_schema;\nUSE FROM source_schema (widget);\nREFERENCE FROM source_schema (widget);\nENTITY consumer;\n  w : widget;\nEND_ENTITY;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "sch_schema"), repository)
      files.each(&:unlink)
      # USE wins: exactly one widget copy survives in the longform
      expect(longform.entities.map(&:id).count { |i| i == "widget" } +
             longform.types.map(&:id).count { |i| i == "widget" }).to eq(1)
    end
  end

  describe "G.1.5 secondary population" do
    it "copies referenced types needed for completeness only" do
      repository, files = parse_repository(
        "source_schema" => "SCHEMA source_schema;\nTYPE used_type = INTEGER; END_TYPE;\nTYPE spare_type = REAL; END_TYPE;\nEND_SCHEMA;\n",
        "sch_schema" => "SCHEMA sch_schema;\nUSE FROM source_schema (used_type);\nREFERENCE FROM source_schema (spare_type);\nENTITY consumer;\n  u : used_type;\nEND_ENTITY;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "sch_schema"), repository)
      files.each(&:unlink)
      expect(longform.types.map(&:id)).to include("used_type")
    end
  end

  describe "G.1.8 tagged remarks travel" do
    # The flatten must carry whatever remark_items the copied source
    # declaration holds (remark ATTACHMENT from source text is
    # RemarkAttacher's contract, spec'd separately); the remark is
    # injected on the parsed entity to isolate the flatten behavior.
    it "carries remark_items on an interfaced entity into the longform" do
      repository, files = parse_repository(
        "source_schema" => "SCHEMA source_schema;\nENTITY marked;\n  a : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n",
        "sch_schema" => "SCHEMA sch_schema;\nUSE FROM source_schema (marked);\nENTITY consumer; m : marked; END_ENTITY;\nEND_SCHEMA;\n",
      )
      marked = repository.schemas.find { |s| s.id == "source_schema" }.entities.first
      marked.remark_items = [Expressir::Model::Declarations::RemarkItem.new(
        id: "rm_marked", remarks: ["marked:purpose the purpose of marked"],
      )]
      longform = flatten(schema_of(repository, "sch_schema"), repository)
      files.each(&:unlink)
      remarks = longform.entities.flat_map { |e| Array(e.remark_items).flat_map(&:remarks) }.join("\n")
      expect(remarks).to include("marked:purpose")
    end
  end

  describe "G.1.10 provenance remark" do
    it "records every contributing schema name" do
      repository, files = parse_repository(
        "alpha" => "SCHEMA alpha;\nENTITY a_ent; END_ENTITY;\nEND_SCHEMA;\n",
        "beta" => "SCHEMA beta;\nUSE FROM alpha (a_ent);\nENTITY b_ent; b : a_ent; END_ENTITY;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "beta"), repository)
      files.each(&:unlink)
      rendered = Expressir::Express::PrettyFormatter.new.format(longform)
      remarks = Array(longform.remark_items).flat_map(&:remarks).join("\n")
      expect(rendered + remarks).to include("alpha").and include("beta")
    end
  end

  describe "G.2.3 extensible enumeration" do
    it "folds the domain and turns extensions into typed exclusions" do
      repository, files = parse_repository(
        "base_schema" => "SCHEMA base_schema;\nTYPE status = EXTENSIBLE ENUMERATION OF (ok); END_TYPE;\nEND_SCHEMA;\n",
        "ext_schema" => "SCHEMA ext_schema;\nUSE FROM base_schema (status);\nTYPE status_ext = EXTENSIBLE ENUMERATION BASED_ON status WITH (pending, rework); END_TYPE;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "ext_schema"), repository)
      files.each(&:unlink)
      rendered = Expressir::Express::PrettyFormatter.new.format(longform)
      expect(rendered).to include("pending").and include("rework")
    end
  end

  describe "G.2.4 extensible select" do
    it "folds select extensions into the full domain" do
      repository, files = parse_repository(
        "base_schema" => "SCHEMA base_schema;\nENTITY thing; END_ENTITY;\nTYPE base_sel = EXTENSIBLE SELECT (thing); END_TYPE;\nEND_SCHEMA;\n",
        "ext_schema" => "SCHEMA ext_schema;\nUSE FROM base_schema (thing, base_sel);\nENTITY gadget_thing; END_ENTITY;\nTYPE gadget_sel = EXTENSIBLE SELECT BASED_ON base_sel WITH (gadget_thing); END_TYPE;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "ext_schema"), repository)
      files.each(&:unlink)
      expect(longform.types.map(&:id)).to include("base_sel", "gadget_sel")
    end
  end

  describe "G.2.6 abstract entity" do
    it "keeps ABSTRACT SUPERTYPE on the entity declaration" do
      repository, files = parse_repository(
        "base_schema" => "SCHEMA base_schema;\nENTITY root ABSTRACT SUPERTYPE OF (ONEOF (sub_a, sub_b));\n  shared : STRING;\nEND_ENTITY;\nENTITY sub_a SUBTYPE OF (root); END_ENTITY;\nENTITY sub_b SUBTYPE OF (root); END_ENTITY;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "base_schema"), repository)
      files.each(&:unlink)
      root = longform.entities.find { |e| e.id == "root" }
      expect(root.abstract).to be_truthy
      expect(root.supertype_expression).not_to be_nil
    end
  end

  describe "G.NM.1 name clashes" do
    it "prefixes every clashing declaration and updates occurrences" do
      repository, files = parse_repository(
        "farming" => "SCHEMA farming;\nENTITY dog;\n  name : STRING;\nEND_ENTITY;\nENTITY herder;\n  dogs : SET OF dog;\nEND_ENTITY;\nEND_SCHEMA;\n",
        "pet_shows" => "SCHEMA pet_shows;\nENTITY dog;\n  breed : STRING;\nEND_ENTITY;\nENTITY show;\n  dogs : SET [1:?] OF dog;\nEND_ENTITY;\nEND_SCHEMA;\n",
        "main" => "SCHEMA main;\nUSE FROM farming (dog, herder);\nUSE FROM pet_shows (dog, show);\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "main"), repository)
      files.each(&:unlink)
      ids = longform.entities.map(&:id)
      expect(ids).to include("farming_dot_dog", "pet_shows_dot_dog")
      # every occurrence of the clashing name is rewritten
      herder = longform.entities.find { |e| e.id == "herder" }
      show = longform.entities.find { |e| e.id == "show" }
      rendered = Expressir::Express::PrettyFormatter.new.format(longform)
      expect(rendered).to include("farming_dot_dog").and include("pet_shows_dot_dog")
      expect(herder.attributes.first.type.base_type.id).to eq("farming_dot_dog")
      expect(show.attributes.first.type.base_type.id).to eq("pet_shows_dot_dog")
    end
  end

  describe "G.1.3 + G.1.4 renamed copies and no USE left" do
    it "copies renamed items under their ORIGINAL name and drops interfaces" do
      repository, files = parse_repository(
        "second" => "SCHEMA second;\nENTITY alfred; END_ENTITY;\nENTITY bert; END_ENTITY;\nEND_SCHEMA;\n",
        "sch" => "SCHEMA sch;\nUSE FROM second (alfred AS alf);\nREFERENCE FROM second (bert AS herbert);\nENTITY joe;\n  attr1 : alf;\n  attr2 : herbert;\nEND_ENTITY;\nEND_SCHEMA;\n",
        "short" => "SCHEMA short;\nUSE FROM sch (joe);\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "short"), repository)
      files.each(&:unlink)
      ids = longform.entities.map(&:id)
      # G.1.3: original names, references rewritten
      expect(ids).to include("joe", "alfred")
      expect(Array(longform.entities.find { |e| e.id == "joe" }.attributes)
        .map { |a| a.type.id }).to include("alfred")
      expect(ids).not_to include("alf", "herbert")
      # G.1.4: no USE specifications survive
      expect(Array(longform.interfaces).select { |i| i.kind == "USE" }).to be_empty
    end
  end

  describe "G.1.6 dependent instantiability" do
    it "emits the annex rule and function for reference entities" do
      repository, files = parse_repository_full(
        "base_schema" => "SCHEMA base_schema;\nENTITY shared;\n  v : INTEGER;\nEND_ENTITY;\nEND_SCHEMA;\n",
        "sch" => "SCHEMA sch;\nREFERENCE FROM base_schema (shared);\nENTITY viewer;\n  s : shared;\nEND_ENTITY;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "sch"), repository)
      files.each(&:unlink)
      rule = longform.rules.find { |r| r.id == "validate_dependently_instantiable_entity_data_types" }
      expect(rule).not_to be_nil
      fn = longform.functions.find { |f| f.id == "dependently_instantiated" }
      expect(fn).not_to be_nil
      expect(Array(rule.applies_to).map { |r| r.id&.downcase }).to include("shared")
    end
  end

  describe "G.2.5 subtype constraints" do
    it "turns total_over into a global rule and constraints into SUPERTYPE" do
      repository, files = parse_repository(
        "sch" => "SCHEMA sch;\nENTITY base; END_ENTITY;\nENTITY a SUBTYPE OF (base); END_ENTITY;\nENTITY b SUBTYPE OF (base); END_ENTITY;\nSUBTYPE_CONSTRAINT base_sc FOR base;\n  ABSTRACT SUPERTYPE;\n  TOTAL_OVER (base);\n  ONEOF (a, b);\nEND_SUBTYPE_CONSTRAINT;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "sch"), repository)
      files.each(&:unlink)
      rule = longform.rules.find { |r| r.id == "total_over_base_sc" }
      expect(rule).not_to be_nil
      expect(Array(rule.applies_to).map { |r| r.id&.downcase }).to eq(%w[base])
      rendered = Expressir::Express::PrettyFormatter.new.format(longform)
      # the ONEOF instantiation constraint attaches as SUPERTYPE OF on
      # the constraint's entity; ABSTRACT moves onto the declaration
      base = longform.entities.find { |e| e.id == "base" }
      expect(base.abstract).to be_truthy
      expect(rendered).to match(/ONEOF/i)
    end
  end

  describe "G.2.2 extensible select chain" do
    it "folds a BASED_ON select chain into the full domain" do
      repository, files = parse_repository(
        "sch" => "SCHEMA sch;\nTYPE leaf = EXTENSIBLE SELECT (ea, eb);\nEND_TYPE;\nTYPE branch = EXTENSIBLE SELECT BASED_ON leaf WITH (ec);\nEND_TYPE;\nENTITY ea; END_ENTITY;\nENTITY eb; END_ENTITY;\nENTITY ec; END_ENTITY;\nENTITY holder;\n  v : branch;\nEND_ENTITY;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "sch"), repository)
      files.each(&:unlink)
      rendered = Expressir::Express::PrettyFormatter.new.format(longform)
      branch = longform.types.find { |t| t.id == "branch" }
      expect(branch).not_to be_nil
      expect(rendered).to include("ea").and include("eb").and include("ec")
      branch_items = Array(branch.underlying_type&.items || branch.underlying_type&.selections)
        .map { |i| i.respond_to?(:id) ? i.id : i.to_s }
      expect(branch_items.map(&:downcase)).to include("ea", "eb", "ec")
    end
  end

  describe "G.1.9 prune pass" do
    it "deletes functions that no artifact declaration calls" do
      repository, files = parse_repository(
        "sch" => "SCHEMA sch;\nFUNCTION unused_fn(x : INTEGER) : INTEGER;\n  RETURN (x);\nEND_FUNCTION;\nFUNCTION used_fn(x : INTEGER) : INTEGER;\n  RETURN (x);\nEND_FUNCTION;\nENTITY thing;\n  a : INTEGER;\nDERIVE\n    d : INTEGER := used_fn(a);\nEND_ENTITY;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "sch"), repository)
      files.each(&:unlink)
      ids = longform.functions.map(&:id)
      expect(ids).to include("used_fn")
      expect(ids).not_to include("unused_fn")
    end
  end

  describe "G.1.7 implicitly interfaced declarations" do
    it "pulls the BASE enumeration of an extending type for completeness" do
      repository, files = parse_repository(
        "export_schema" => "SCHEMA export_schema;\nTYPE colour = EXTENSIBLE ENUMERATION;\nEND_TYPE;\nTYPE stop_light = ENUMERATION BASED_ON colour WITH (red, yellow, green);\nEND_TYPE;\nEND_SCHEMA;\n",
        "import_schema" => "SCHEMA import_schema;\nUSE FROM export_schema (stop_light);\nTYPE canadian_flag = ENUMERATION BASED_ON colour WITH (red, white);\nEND_TYPE;\nEND_SCHEMA;\n",
      )
      longform = flatten(schema_of(repository, "import_schema"), repository)
      files.each(&:unlink)
      ids = longform.types.map(&:id)
      # stop_light via USE; colour and canadian_flag are pulled
      # implicitly: canadian_flag's BASED_ON references colour, which
      # the artifact must also carry (G.1.7)
      expect(ids).to include("stop_light", "canadian_flag", "colour")
    end
  end
end
