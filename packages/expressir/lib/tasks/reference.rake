# frozen_string_literal: true

namespace :reference do
  desc "Regenerate the grammar cross-walk guide"
  task :crosswalk do
    require "expressir"

    path = Expressir.root_path.join(
      "docs/_guides/reference/grammar-crosswalk.adoc",
    )
    File.write(path, Expressir::Reference::GrammarCrosswalk.render_adoc)
    puts "wrote #{path}"
  end

  desc "Regenerate the checker note-id catalog"
  task :notes do
    require "expressir"

    path = Expressir.root_path.join(
      "docs/_guides/reference/checker-notes.adoc",
    )
    File.write(path, Expressir::Reference::NoteCatalog.render_adoc)
    puts "wrote #{path}"
  end
end
