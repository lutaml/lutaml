fix-lint-staged:
	git status --short | egrep '^(A|M)' | awk '{ print $$2}' | grep -v db/schema.rb | xargs bundle exec rubocop -a
