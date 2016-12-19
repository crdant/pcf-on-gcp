# get a random adjective-noun phrase using the same source files as random routes in CF
#    outputs the phrase

CF_CLI_GITHUB_RAW_ROOT="https://raw.githubusercontent.com/cloudfoundry/cli/master"
adjective_file="$TMPDIR/adjectives.txt"
noun_file="$TMPDIR/nouns.txt"
delimiter="-"

if [ ! -f "${adjective_file}" ] ; then
  curl -qsLf -o "${adjective_file}" "${CF_CLI_GITHUB_RAW_ROOT}/util/words/dict/adjectives.txt"
fi
adjective_lines=`wc -l ${adjective_file} | awk '{ print $1 }'`


if [ ! -f "${noun_file}" ] ; then
  curl -qsLf -o "${noun_file}" "${CF_CLI_GITHUB_RAW_ROOT}/util/words/dict/nouns.txt"
fi
noun_lines=`wc -l ${noun_file} | awk '{ print $1 }'`

generate_passphrase () {
  words=$1

  counter=0
  passphrase=""
  while [ $counter -lt $words ] ; do
    if [ $((RANDOM%2)) -eq 0 ] ; then
      file=$adjective_file
      index=$((RANDOM*RANDOM%$adjective_lines+1));
    else
      file=$noun_file
      index=$((RANDOM*RANDOM%$noun_lines+1));
    fi
    word=`sed -n "$index p" "${file}"`
    passphrase="${passphrase}${word}"
    let counter=counter+1
    if [ $counter -lt $words ] ; then
      passphrase="${passphrase}${delimiter}"
    fi
  done

  echo "${passphrase}"
}
