script_full_path=$(dirname "$0")

for i in $1/*.yml
do
$script_full_path/yaml2lutaml $i > "$1/$(basename -s .yml $i).lutaml"
done