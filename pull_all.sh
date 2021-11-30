GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
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
  changed=$(echo "$out" | grep -w "changed.")

  repos_left=$(cat "$working_dir/.repos_left")
  repos_left=$((repos_left - 1))
  echo "$repos_left" > "$working_dir/.repos_left" 
  curr=$((total_repos - repos_left))

  if [ $? -eq 0 ]; then
    echo -e "$curr. ${GREEN}done${NC} -> $repo"
    [ $changed ] && echo "$changed"
  else
    echo -e "$curr. ${RED}fail${NC} -> $repo"
    echo -e "$out"
  fi
}

folders=( $(ls -d $pattern | sed -r 's/\/\.git$//g') )

total_repos=${#folders[@]}
export total_repos

working_dir=$(pwd)
export working_dir

repos_left=${#folders[@]}
echo "$repos_left" > "$working_dir/.repos_left"

echo -e "Starting to pull from ${CYAN}$total_repos${NC} repositories"

for folder in ${folders[@]}; do
  parallel_jobs=$(jobs | wc -l)
  while [ $parallel_jobs -gt $max_parallel_jobs ]; do
    sleep 0.3
  done
  pull $folder &
done

wait

rm "$working_dir/.repos_left"
