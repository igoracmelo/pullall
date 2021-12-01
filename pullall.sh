GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
ORANGE='\033[0;33m'
NC='\033[0m'

max_parallel_jobs=10
pattern="*"

[ "$1" ] && pattern="$1"
[ "$2" ] && max_parallel_jobs=$2

pattern="$pattern/.git"

function pull() {  
  repo="$1"
  cd "$repo"

  out=$(git pull --all 2>&1)
  msg=$(echo "$out" | egrep "changed\.|up to date\.")

  repos_left=$(cat "$working_dir/.repos_left")
  repos_left=$((repos_left - 1))
  echo "$repos_left" > "$working_dir/.repos_left" 
  curr=$((total_repos - repos_left))

  if [ $? -eq 0 ]; then
    echo -e "$curr. ${GREEN}done${NC} -> $repo"
    echo "$msg"
  else
    echo -e "$curr. ${RED}fail${NC} -> $repo"
    echo -e "$out"
  fi
	echo
}

function onsigint() {
  repos_left=$(cat "$working_dir/.repos_left")
  echo
	echo -e "${ORANGE}Script interrupted by user${NC}"
	echo -e "${RED}$repos_left${NC} repositories weren't updated"
  exit 2
}

trap onsigint 2

folders=( $(ls -d $pattern | sed -r 's/\/\.git$//g') )

total_repos=${#folders[@]}
export total_repos

working_dir=$(pwd)
export working_dir

repos_left=${#folders[@]}
echo "$repos_left" > "$working_dir/.repos_left"

echo -e "Starting to pull from ${CYAN}$total_repos${NC} repositories"
echo

for folder in ${folders[@]}; do
  parallel_jobs=$(jobs | wc -l)
  while [ $parallel_jobs -gt $max_parallel_jobs ]; do
    sleep 0.3
  done
  pull $folder &
done

wait

rm "$working_dir/.repos_left"
