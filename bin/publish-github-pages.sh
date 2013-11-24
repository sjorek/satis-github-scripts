#!/usr/bin/env bash
set -e # Stop on the first failure that occurs

if [ ! -x vendor/bin/satis ]; then
	echo "Please install this package in development-mode if you want to publish satis to github-pages."
	exit 1
fi

echo "TARGET_REMOTE :" ${TARGET_REMOTE:=${1:-origin}}
echo "TARGET_BRANCH :" ${TARGET_BRANCH:=${2:-gh-pages}}
echo "GITHUB_URL    :" ${GITHUB_URL:=${3:-$(git config --get remote.${TARGET_REMOTE}.url | grep "github.com" )}}

if [ -z "${GITHUB_URL}" ] ; then
	echo "GITHUB_USER   :" ${GITHUB_USER:=${4:-$(git config --get github.user)}}
	echo "GITHUB_REPO   :" ${GITHUB_REPO:=${5:-$(php -r '$parts=explode("/",json_decode(file_get_contents("composer.json"))->name); echo array_pop($parts);')}}
else
	echo "GITHUB_USER   :" ${GITHUB_USER:=${4:-$(echo ${GITHUB_URL} | sed -e "s|^.*github\.com[:\/]\(.*\)\/.*\.git$|\1|")}}
	echo "GITHUB_REPO   :" ${GITHUB_REPO:=${5:-$(echo ${GITHUB_URL} | sed -e "s|^.*github\.com[:\/].*\/\(.*\)\.git$|\1|")}}
fi

echo "SATIS_NAME    :" ${SATIS_NAME:=${6:-$(php -r 'echo json_decode(file_get_contents("composer.json"))->name;')}}
echo "SATIS_PATH    :" ${SATIS_PATH:=${7:-.git/satis}}
echo "SATIS_FILE    :" ${SATIS_FILE:=${8:-satis.json}}
echo "SATIS_URL     :" ${SATIS_URL:=${9:-$(php -r 'echo json_decode(file_get_contents("composer.json"))->homepage;')}}
echo "SATIS_PREFIX  :" ${SATIS_PREFIX:=${10:-/${GITHUB_REPO}}}

# Git spits out status information on $stderr, and we don't want to relay that as an error to the
# user.  So we wrap git and do error handling ourselves...
exec_git() {
	args=''
	for (( i = 1; i <= $#; i++ )); do
		eval arg=\$$i
		if [[ $arg == *\ * ]]; then
			# } We assume that double quotes will not be used as part of argument values.
			args="$args \"$arg\""
		else
			args="$args $arg"
		fi
	done

	set +e

	# } Even though we wrap the arguments in quotes, bash is splitting on whitespace within.  Why?
	result=$(eval git $args 2>&1)
	status=$?
	set -e

	if [[ $status -ne 0 ]]; then
		echo "$result" >&2
		exit $status
	fi

	echo "$result"
	return 0
}

if [[ $( git status -s ) != "" ]]; then
	echo "Please commit or stash your changes before publishing documentation to github!" >&2
	exit 1
fi

CURRENT_BRANCH=$( git branch 2>/dev/null| sed -n '/^\*/s/^\* //p' )
CURRENT_COMMIT=$( git rev-parse HEAD )
CURRENT_DIR=$( pwd )

if [ ! -d "${SATIS_PATH}" ] ; then

	if [[ $(git branch --no-color | grep " $TARGET_BRANCH") == "" ]]; then
		# Do a fetch from the target remote to see if it was created remotely
		exec_git fetch $TARGET_REMOTE

		# Does it exist remotely?
		if [[ $(git branch -a --no-color | grep " remotes/$TARGET_REMOTE/$TARGET_BRANCH") == "" ]]; then
			echo "No '$TARGET_BRANCH' branch exists.  Creating one"
			exec_git checkout --orphan $TARGET_BRANCH
			[ -e .gitignore ] && cp .gitignore .gitignore~
			exec_git rm -r .
			[ -e .gitignore~ ] && mv .gitignore~ .gitignore
			[ -e .gitignore ] || touch .gitignore
			exec_git add .gitignore
			exec_git commit -m "created empty “gh-pages” branch"
			exec_git push $TARGET_REMOTE $TARGET_BRANCH
		else
			# TARGET_REMOTE=origin # Wtf ?
			echo "No local branch '$TARGET_BRANCH', checking out '$TARGET_REMOTE/$TARGET_BRANCH' and tracking that"
			exec_git checkout -b $TARGET_BRANCH $TARGET_REMOTE/$TARGET_BRANCH
		fi

	else
		exec_git checkout $TARGET_BRANCH
	fi
	exec_git clone --local --reference . --single-branch -b $TARGET_BRANCH . ${SATIS_PATH}

	# Restore previous state !
	exec_git checkout $CURRENT_BRANCH
fi

if [ ! -e "${SATIS_PATH}/.git" ] ; then
	echo "Path “${SATIS_PATH}” is not a git-repository."
	exit 1
fi

cd ${SATIS_PATH}
exec_git pull

if [ -e "${SATIS_FILE}" ] ; then
	SATIS_JSON=$(cat ${SATIS_FILE})
else
	SATIS_JSON=$(cat <<EOF | tee ${SATIS_FILE}
{
	"name"                 : "${SATIS_NAME}",
	"homepage"             : "${SATIS_URL}",
	"output-dir"           : "${SATIS_PATH}",
	"repositories"         : [],
	"require-all"          : true,
	"require-dependencies" : true,
	"archive"              : {
		"directory"        : "archive",
		"format"           : "zip",
		"prefix-url"       : "${SATIS_PREFIX}",
		"skip-dev"         : true
	}
}
EOF
)

	exec_git add ${SATIS_FILE}
	exec_git commit -m "added satis-repository configuration skeleton “${SATIS_FILE}”"
	exec_git push
fi

echo "SATIS_JSON    :"
echo ${SATIS_JSON}

# We want to keep in complete sync (deleting old docs, or cruft from previous documentation output).
# Preserve the project's .gitignore and satis.json, so that we don't check in or otherwise screw up
# hidden files.
exec_git ls-files | grep -v -E "^(\\.gitignore|satis.json)$" | xargs rm -r

# Run satis …
( cd ${CURRENT_DIR} && php vendor/bin/satis -vvv build ${SATIS_PATH}/${SATIS_FILE} )

# Do nothing unless we actually have changes
if [[ $(git status -s) != "" ]]; then
	exec_git add -A
	exec_git commit -m "Generated satis-repository for $CURRENT_COMMIT"
	exec_git push
fi

cd ${CURRENT_DIR}
# Publish state
exec_git push $TARGET_REMOTE $TARGET_BRANCH
