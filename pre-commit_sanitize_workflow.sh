#!/bin/sh
#
# A hook script to remove BOM headers from GitHub worfklows
# Modified slightly from https://gist.github.com/rlee287/e6026243dedc38398298 , thank you rlee287

echo "Running pre-commit BOM removal"

trap ctrl_c INT

ctrl_c ()
{
    if [ -f $templist ]; then
        rm $templist;
    fi
    if [ -f $checkam ]; then
        rm $checkam
    fi
    if [ -f $statfile ]; then
        rm $statfile
    fi
    exit
}

isBinary()
{
    p=$(printf '%s\t-\t' -)
    t=$(git diff --no-index --numstat /dev/null "$1")
    case "$t" in "$p"*) return 0 ;; esac
    return 1
}

templist=$(mktemp "/tmp/git_sed_remove.XXXXXXXX")
statfile=$(mktemp "/tmp/git_sed_remove.XXXXXXXX")
checkam=$(mktemp "/tmp/git_sed_remove.XXXXXXXX")
listchange=$(git diff --cached --name-only --diff-filter="AMRCB")
stat=$(git status --porcelain)
echo "${stat}" >> $statfile
awk 'match($1, "*M")' $statfile > $checkam

if [ -s $checkam ]; then
    echo "Files have been modified since they were added"
    echo "This script will add new modifications"
    echo "Please add them first"
    exit 1
fi
echo "${listchange}" > $templist

for file in $(cat $templist)
do
    isBinary $file
    if [ $? != 0 ]; then
        echo "Checking text file $file"
        #grep '1 s/^\xef\xbb\xbf//' $file
        sed --quiet '0,/^\xef\xbb\xbf/{//q8;}' $file
        if [ $? = 8 ]; then
            #remove UTF-8
            echo "Stripping UTF-8 BOM headers from $file"
            sed --in-place '1 s/^\xef\xbb\xbf//' $file
        fi
        sed --quiet '0,/^\xfe\xff/{//q16;}' $file
        if [ $? = 16 ] && [ "$file" == *".github/workflows"*]; then
            #remove UTF-16
            echo "Stripping UTF-16 BOM headers from GitHub Workflow file $file"
            sed --in-place '1 s/^\xfe\xff//' $file
        fi
        git add $file &> /dev/null
    else
        echo "Skipped binary file $file"
    fi
done

# If there are whitespace errors, print the offending file names and fail.
#exec git diff-index --check --cached $against --
ctrl_c