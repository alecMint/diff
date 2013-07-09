#!/bin/bash
# sh ../diff/diff.sh -a alec -o -w -t 7 -b
# -a authors override
# -o open relevant files
# -w write HEAD files
# -t cutoff time for authorship
# -b makes new branch off of production tag
# -q tag override

validAuthors=('alec' 'brian' 'ryan' 'harold')
WRITETO=`dirname $0`'/tmp/'
WRITESEP='\n\n\n'

customAuthors=
OPEN=0
WRITE=0
cutoffTime=0
CUTBRANCH=0
tagOverride=0
while getopts ':a:owt:bq:' opt; do
    case $opt in
        a)
            customAuthors=$OPTARG
        ;;
        o)
            OPEN=1
        ;;
        w)
            WRITE=1
        ;;
        t)
            cutoffTime=$OPTARG
        ;;
        b)
            CUTBRANCH=1
        ;;
        q)
            tagOverride=$OPTARG
        ;;
    esac
done
if [ $customAuthors ]; then
    validAuthors=()
    IFS=','
    i=0
    for customAuthor in $customAuthors; do
        validAuthors[i]=$customAuthor
        i=$[i+1]
    done
fi
echo 'Valid Authors: '${validAuthors[*]}

if [ $WRITE == 1 ]; then
    echo 'Writing to: '$WRITETO
    if [ ! -d $WRITETO ]; then
        mkdir $WRITETO
    fi
    #not working, fix
    #rm -fr $WRITETO'*'
    writeDiff=$WRITETO'diff.txt'
    touch $writeDiff
    echo '' > $writeDiff
fi

if [ $cutoffTime != 0 ]; then
    echo 'Date Cutoff: '$cutoffTime' days ago'
    cutoffTime=$[`date +%s` - $cutoffTime*60*60*24]
fi


isValidAuthor() {
    for authorIVA in ${validAuthors[*]}; do
        if [ $1 == $authorIVA ]; then
            echo '1'
            break
        fi
    done
}
fileIsRelevant() {
    IFS=$'\n'
    authorsFIR_=`git --no-pager log $1 2>/dev/null | grep -oP 'Author:\s*\K([^ ]+)'`
    authorsFIR=()
    iFIR=0
    for authorFIR in $authorsFIR_; do
        authorsFIR[$iFIR]=$authorFIR
        iFIR=$[iFIR+1]
    done
    datesFIR_=`git --no-pager log $1 2>/dev/null | grep -oP 'Date:\s*\K(.+)'`
    datesFIR=()
    iFIR=0
    for dateFIR in $datesFIR_; do
        datesFIR[$iFIR]=$dateFIR
        iFIR=$[iFIR+1]
    done
    iFIR=0
    for authorFIR in ${authorsFIR[@]}; do
        if [ $cutoffTime != 0 ]; then
            tzOffsetString=`echo ${datesFIR[$iFIR]} | grep -oP '.+ \K(.+)$'`
            tzOffset=`echo $tzOffsetString | sed 's/\(-\)*0*\([1-9]\)/\1\2/'`
            tzOffset=$[$tzOffset/100*60*60]
            logTime=`echo ${datesFIR[$iFIR]} | grep -oP '\K([^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+)'`
            logTime=`date -j -f "%a %b %d %T %Y" "$logTime" "+%s"`
            if [ $logTime -lt $cutoffTime ]; then
                break
            fi
        fi
        if [ `isValidAuthor ${authorFIR}` ]; then
            echo '1'
            break
        fi
        iFIR=$[iFIR+1]
    done
}


repo=`git remote -v | head -n1 | awk '{print $2}'`
if [ $repo == 'git@github.com:beachmint/api' ]; then
    url='http://api-prod.beachmintdev.com/cnf.php'
elif [ $repo == 'git@github.com:beachmint/mint-js' ]; then
    url='http://prod-mint-js.beachmintdev.com/cnf.php'
elif [ $repo == 'git@github.com:beachmint/jewelmint-p' ]; then
    url='http://www.jewelmint.com/cnf.php'
else
    echo 'Unknown repo'
    exit
fi

if [ $tagOverride == 0 ]; then
    cnf=`curl -s $url`
    tag=`echo $cnf | grep -oP '"tag":"\K([^"]+)'`
else
    tag=$tagOverride
fi

if [ $tag == '' ]; then
    echo 'Production not checked out to tag'
    exit
fi

echo 'Production tag: '$tag


diff=`git --no-pager diff $tag..HEAD`
if [ $WRITE == 1 ]; then
    echo "git --no-pager diff $tag..HEAD"$WRITESEP >> $writeDiff
fi

IFS=$'\n'
writeLine=0
for line in $diff; do
    file=`echo $line | grep -oP 'diff --git a/\K([^ \n]+)'`

    if [ $file ]; then
        if [ $WRITE == 1 ] && [ $writeLine == 1 ]; then
            echo $WRITESEP >> $writeDiff
            writeLine=0
        fi

        if [ `fileIsRelevant "$file"` ]; then
            writeLine=1
            if [ $OPEN == 1 ]; then
                open $file
            else
                echo $file
            fi
            if [ $WRITE == 1 ]; then
                headFileName=`basename $file`
                headDirectory=`dirname $file`
                headFileName=$WRITETO$headDirectory'/HEAD.'$headFileName
                `mkdir -p $WRITETO$headDirectory`
                touch $headFileName
                cat $file > $headFileName
                if [ $OPEN == 1 ]; then
                    open $headFileName
                else
                    echo 'Backup created: '$headFileName
                fi
            fi
        fi
    fi

    if [ $WRITE == 1 ] && [ $writeLine == 1 ]; then
        echo $line >> $writeDiff
    fi
done

if [ $WRITE == 1 ] && [ $OPEN == 1 ]; then
    open $writeDiff
fi

if [ $CUTBRANCH == 1 ]; then
    abc=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
    letter=`echo $tag | grep -oP '[0-9]+\K([a-z])'`
    if [ $letter == '' ] || [ $letter == 'z' ]; then
        echo 'Cannot create branch. Unconventional tag name in production'
    else 
        i=0
        for l in ${abc[@]}; do
            i=$[i+1]
            if [ $letter == $l ]; then
                break
            fi
        done
        nextLetter=${abc[$i]}
        branchName=`echo $tag | sed "s/$letter/$nextLetter/"`
        `git checkout $tag`
        `git checkout -b tag_$branchName`
    fi
fi

echo "Done"