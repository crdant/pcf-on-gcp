# get a random adjective-noun phrase using the same source files as random routes in CF
#    outputs the phrase

CF_CLI_GITHUB_RAW_ROOT="https://raw.githubusercontent.com/cloudfoundry/cli/master"
adjective_file="$WORKDIR/adjectives.txt"
noun_file="$WORKDIR/nouns.txt"

if [ ! -f "${adjective_file}" ] ; then
  curl -qsLf -o "${adjective_file}" "${CF_CLI_GITHUB_RAW_ROOT}/util/words/dict/adjectives.txt"
fi
adjective_lines=`wc -l $adjective_file | awk '{ print $1 }'`


if [ ! -f "${noun_file}" ] ; then
  curl -qsLf -o "${noun_file}" "${CF_CLI_GITHUB_RAW_ROOT}/util/words/dict/nouns.txt"
fi
noun_lines=`wc -l $noun_file | awk '{ print $1 }'`

random_phrase () {
  adjective_index=$((RANDOM*RANDOM%$adjective_lines+1));
  noun_index=$((RANDOM*RANDOM%$noun_lines+1));
  echo `sed -n "$adjective_index p" "${adjective_file}"`'-'`sed -n "$noun_index p" "${noun_file}"`
}
