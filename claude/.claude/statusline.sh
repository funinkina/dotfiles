#!/usr/bin/env bash
# Claude Code status line: reads session JSON on stdin, prints two rows.
# Row 1: model / effort / dir / git / pr / agent
# Row 2: context bar / tokens / cost / duration / diff / rate limits
# Schema: https://code.claude.com/docs/en/statusline
set -uo pipefail
export LC_ALL=C

input=$(cat)

mapfile -t F < <(printf '%s' "$input" | jq -r '
  [ .model.display_name                              // "?"
  , .effort.level                                    // ""
  , (.fast_mode                                      // false | tostring)
  , (.workspace.current_dir // .cwd                  // "")
  , (.context_window.used_percentage      // 0 | floor | tostring)
  , (.context_window.total_input_tokens   // 0 | tostring)
  , (.context_window.total_output_tokens  // 0 | tostring)
  , (.context_window.context_window_size  // 200000 | tostring)
  , (.cost.total_cost_usd                 // 0 | tostring)
  , (.cost.total_duration_ms              // 0 | tostring)
  , (.cost.total_lines_added              // 0 | tostring)
  , (.cost.total_lines_removed            // 0 | tostring)
  , (.rate_limits.five_hour.used_percentage  // "" | tostring)
  , (.rate_limits.seven_day.used_percentage  // "" | tostring)
  , .agent.name                                      // ""
  , (.pr.number                              // "" | tostring)
  ] | .[]' 2>/dev/null)

# jq failed or gave short output -> degrade instead of printing nothing
((${#F[@]} >= 16)) || F=("?" "" "false" "$PWD" 0 0 0 200000 0 0 0 0 "" "" "" "")

model=${F[0]} effort=${F[1]} fast=${F[2]} dir=${F[3]}
pct=${F[4]} tin=${F[5]} tout=${F[6]} ctxmax=${F[7]}
cost=${F[8]} durms=${F[9]} added=${F[10]} removed=${F[11]}
rl5=${F[12]} rl7=${F[13]} agent=${F[14]} pr=${F[15]}
[[ -n $dir ]] || dir=$PWD

R=$'\033[0m'  D=$'\033[2m'
MAG=$'\033[1;35m' BLU=$'\033[1;34m' GRN=$'\033[32m' YEL=$'\033[33m' RED=$'\033[31m' CYN=$'\033[36m'

human() { # tokens -> 842 / 56.2k / 200k / 1M
  local n=$1 whole frac unit
  if   ((n >= 1000000)); then whole=$((n/1000000)) frac=$(((n%1000000)/100000)) unit=M
  elif ((n >= 1000));    then whole=$((n/1000))    frac=$(((n%1000)/100))       unit=k
  else printf '%d' "$n"; return; fi
  ((frac == 0)) && printf '%d%s' "$whole" "$unit" || printf '%d.%d%s' "$whole" "$frac" "$unit"
}

dur() { # ms -> 45s / 12m / 1h5m
  local s=$(($1/1000))
  if   ((s >= 3600)); then printf '%dh%dm' $((s/3600)) $(((s%3600)/60))
  elif ((s >= 60));   then printf '%dm' $((s/60))
  else printf '%ds' "$s"; fi
}

bar() { # pct -> 10-cell meter
  local filled=$(($1/10)) i out=''
  ((filled > 10)) && filled=10
  ((filled < 0))  && filled=0
  for ((i=0; i<10; i++)); do ((i < filled)) && out+='▓' || out+='░'; done
  printf '%s' "$out"
}

heat() { ((  $1 >= 85 )) && printf '%s' "$RED" || { (( $1 >= 60 )) && printf '%s' "$YEL" || printf '%s' "$GRN"; }; }

cols=${COLUMNS:-100}
sep="${D} · ${R}"

# ---------- row 1 ----------
l1="${MAG}${model}${R}"
[[ -n $effort ]]      && l1+="${D}:${effort}${R}"
[[ $fast == true ]]   && l1+=" ${YEL}⚡${R}"
l1+="  ${BLU}${dir/#$HOME/\~}${R}"

if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
  branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null \
           || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  read -r st md un < <(git -C "$dir" status --porcelain=v1 2>/dev/null | awk '
    /^\?\?/ { u++; next }
    { x=substr($0,1,1); y=substr($0,2,1)
      if (x != " " && x != "?") s++
      if (y != " " && y != "?") m++ }
    END { printf "%d %d %d", s+0, m+0, u+0 }')
  [[ -n ${branch:-} ]] && l1+="  ${GRN}⎇ ${branch}${R}"
  flags=''
  ((${st:-0} > 0)) && flags+="${GRN}+${st}${R}"
  ((${md:-0} > 0)) && flags+="${YEL}~${md}${R}"
  ((${un:-0} > 0)) && flags+="${D}?${un}${R}"
  [[ -n $flags ]] && l1+=" $flags"
fi

[[ -n $pr ]]    && l1+="  ${CYN}#${pr}${R}"
[[ -n $agent ]] && l1+="  ${D}[${agent}]${R}"

# ---------- row 2 ----------
hot=$(heat "$pct")
l2="${hot}$(bar "$pct")${R} ${hot}${pct}%${R}"
l2+="${sep}${CYN}$(human "$tin")${R}${D}/$(human "$ctxmax")${R}"
l2+="${sep}${D}↑${R}$(human "$tout")"
l2+="${sep}${YEL}\$$(printf '%.2f' "$cost")${R}"
l2+="${sep}$(dur "$durms")"

if ((cols >= 90)); then
  ((added > 0 || removed > 0)) && l2+="${sep}${GRN}+${added}${R}${D}/${R}${RED}-${removed}${R}"
fi
if ((cols >= 100)); then
  [[ -n $rl5 ]] && l2+="${sep}${D}5h${R} ${rl5%%.*}%"
  [[ -n $rl7 ]] && l2+="${sep}${D}7d${R} ${rl7%%.*}%"
fi

printf '%s\n%s\n' "$l1" "$l2"
