GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
ORANGE='\033[0;33m'
NC='\033[0m'

max_parallel_jobs=15
pattern="*"

[ "$1" ] && pattern="$1"
[ "$2" ] && max_parallel_jobs=$2

pattern="$pattern/.git"

function pull() {
  repo="$1"
  cd "$repo"

  out=$(git pull --all 2>&1)
  code="$?"
  msg=$(echo "$out" | egrep "changed|insertions|deletions|up to date\.")

  repos_left=$(cat "$wd/.repos_left" | grep -vxF "$repo")
  repos_count=$(echo -n "$repos_left" | grep -c ^)

  echo -n "$repos_left" > "$wd/.repos_left"
  curr=$((total_repos - repos_count))

  if [ $code -eq 0 ]; then
    echo -e "$curr. ${GREEN}done${NC} -> $repo"
    [ "$msg" ] && echo "$msg" || echo "$out"
  else
    echo -e "$curr. ${RED}fail${NC} -> $repo"
    echo -e "$out"
    echo "$repo" >> "$wd/.repos_failed"
  fi
  echo
}

function onsigint() {
  repos=( $(cat "$wd/.repos_left") )
  echo
  echo -e "${ORANGE}Script interrupted by user${NC}"
  echo -e "${RED}${#repos[@]}${NC} repositories weren't updated:"
  echo "${repos[@]}"
  echo
  
  repos_failed=( $(cat "$wd/.repos_failed" 2> /dev/null) )

  if [ $? -eq 0 ]; then
    echo -e "${RED}${#repos_failed[@]}${NC} repositories failed to update:"
    echo "${repos_failed[@]}"
  fi

  rm "$wd/.repos_left"
  rm "$wd/.repos_failed" 2> /dev/null
  exit 2
}

trap onsigint 2

folders=( $(ls -d $pattern | sed -r 's/\/\.git$//g') )

total_repos=${#folders[@]}
export total_repos

wd=$(pwd)
export wd

echo -n "" > .repos_left
echo -n "" > .repos_failed

for folder in ${folders[@]}; do
  echo $folder >> "$wd/.repos_left"
done

echo -e "Starting to pull from ${CYAN}${#folders[@]}${NC} repositories"
echo

for folder in ${folders[@]}; do
  parallel_jobs=$(jobs | grep -c ^)
  while [ $parallel_jobs -gt $max_parallel_jobs ]; do
    sleep 0.3
  done
  pull $folder &
done

wait

repos_failed=( $(cat "$wd/.repos_failed" 2> /dev/null) )

if [ $? -eq 0 ]; then
  echo -e "${RED}${#repos_failed[@]}${NC} repositories failed to update:"
  echo "${repos_failed[@]}"
fi

rm "$wd/.repos_left"
rm "$wd/.repos_failed" 2> /dev/null
