#!/bin/bash

######################################################################
#
# Description:
#
# This framework uses $WS_BASE_DIR variable so be aware to set it:)
#
######################################################################
USAGE='''
\n?) each flag you can use as shortcut e.g: "--run" equal "-r" or "r" e.g.2: ./rtest r
\n0) ./rtest.sh --help                      # Print this help
\n1) ./rtest.sh                         # Print list of rtests for current testcase
\n2) ./rtest.sh --run                       # Run all rtests print results (SUCCESS or FAIL) for current testcase
\n3) ./rtest.sh rtest-name/sequence-test-number         # Run rtest and validate the results by diff
\n4) ./rtest.sh rtest-name/sequence-test-number --update    \t# Run and update specyfic rtest
\n5) ./rtest.sh rtest-name/sequence-test-number --print     \t# print references of specyfic rtest
\n6) ./rtest.sh 0 2 1 3 rtest-name              # Run custom sequence of rtests
\n7) ./rtest.sh --edit                      # Edit current testcase
\n8)./rtest.sh --logs                       # show logs
\n\t### Independent options ###
\n9) --suite[s]                         # Print list of testcases
\n10)--suite[s] 1                       \t# Pick up the testcase by number
\n11)--build                            # Set env to use the newest libs and bins from LocalBuild. Default local variables
\n12)--init                         # Set baseline from nexus to dir input/baseline
\n
'''

############### stderr handler block
errmsg=0
echomod()
{
    echo " $@" 1>&2;
}
trap "exit 1" TERM
echoerror="eval echomod \"Error \`basename \"$0\"\`:\${LINENO}\""
################
############## COLORS #####
export RED="\x1b[91m"
export GREEN="\x1b[32m"
export BLUE="\x1b[34m"
export CYAN="\x1b[36m"
export MAGENTA="\x1b[35m"
export YELLOW="\x1b[33m"
export END="\x1b[0m"
#printf "${GREEN}SUCCESS${END}\n${BLUE}UPDATED${END}\n${RED}FAIL${END}\n"
###############

if [ -z ${BASH_SOURCE- } ];
then
    export TEST_DIR=$(realpath `dirname $0`)
else
    export TEST_DIR=$(realpath `dirname $BASH_SOURCE`)
fi

export REFERENCES="$TEST_DIR/references"
export OUTPUTS="$TEST_DIR/outputs"
export INPUTS="$TEST_DIR/inputs"
export OTHERS="$TEST_DIR/others"
export LOGS="$TEST_DIR/logs"
export SUITES="$TEST_DIR/suites"
export SCRIPTS="$TEST_DIR/scripts"
TEST_CASE=""
TEST_CASE_CONTENT=""

. $SCRIPTS/config.sh

unset BUILD_ENV
unset RSUITE RSUITE_VAL
unset RINIT
params=( $* )
for i in "${!params[@]}"; do
    if [[ ${params[$i]} == 'b' ]] || [[ ${params[$i]} == '-b' ]] || [[ ${params[$i]} == '--build' ]] ;
    then
        export BUILD_ENV="TRUE"
        unset params[$i]        #remove flag
    elif [[ ${params[$i]} == 's' ]] || [[ ${params[$i]} == '-s' ]] || [[ ${params[$i]} == '--suite' ]] || [[ ${params[$i]} == '--suites' ]];
    then
        export RSUITE="TRUE"
        export RSUITE_VAL="${params[$((i+1))]}"
        unset params[$i]        #remove flag
        unset params[$((i+1))]      #remove following element
    elif [[ ${params[$i]} == 'i' ]] || [[ ${params[$i]} == '-i' ]] || [[ ${params[$i]} == '--init' ]];
    then
        export RINIT="TRUE"
        unset params[$i]        #remove flag
    fi
done
set -- "${params[@]}"

if [[ "$RINIT" == 'TRUE' ]]
then
    echo "NOTHING TO INIT" #$SCRIPTS/init.sh
fi

#echo  "$# $@"      #print amount and values of parameters
#params=( $* )      #assign array
#unset params[2]    #remove element
#set -- "${params[@]}"  #set rest of parameters to global vars "$1 $2 $3 ..."
#echo  "$# $@"      #print amount and values of parameters

if [ "$BUILD_ENV" != "TRUE" ] ;
then
    export PATHDIR=""
    export LD_LIBRARY_PATHDIR=""
fi

FixSuiteName ()
{
    if [ -z ${1+$1} ]; then
        $echoerror "You need set at last one param" ; kill -s TERM $$
    fi
    CASE=`echo $1 | awk -F "suites/" '{print $NF}'`
    i=0
    while IFS= read -r line;
    do
        if [[ "$CASE" == "$i" ]] || [[ "$CASE" == "$line" ]];
        then
            echo "${SUITES}/${line}"
            exit 0
        fi
        ((i=i+1));
    done < <(find $SUITES -type f |  grep -v "\.swp$\|default$\|current$" | awk -F "suites/" '{print $NF}' )
    echo "${SUITES}/${CASE}"
}

if [ -f "${SUITES}/current" ];
then
    TEST_CASE=`cat "${SUITES}/current"`

elif [ -f "${SUITES}/default" ];
then
    TEST_CASE="$SUITES/`cat $SUITES/default`"
else
    TEST_CASE="$SUITES/testcases"
    touch $TEST_CASE
fi

printf "\n${YELLOW}USING TESTCASES${END}: $TEST_CASE\n"

loadRtestsContent()
{
    if [ -z ${1+$1} ]; then
        $echoerror "You need set at last one param" ; kill -s TERM $$
    fi
    while IFS= read -r line;
    do
        if [[ "$line" == *"INCLUDE_TESTCASE"*  ]];
        then
            loadRtestsContent "$SUITES/`echo $line | awk '{print $2}'`"
        fi
        echo $line | awk -F '#' '{print $1}'
    done < <(cat $1 )
}
fillRtestContent()
{
    set -f
    TEST_CASE_CONTENT=`loadRtestsContent $TEST_CASE`
    set +f
}
################

printRtests()
{
    printf "${TEST_CASE_CONTENT}" | grep "BEGIN_TEST" | grep -v "DISABLED_TEST" | awk '{print $2}'
}

declare -A DIC_RTESTS

fillRtestDict()
{
    fillRtestContent
    unset 'DIC_RTESTS[@]'
    i=0
    while IFS= read line;
    do
        DIC_RTESTS+=(["$i"]="$line");
        ((i=i+1));
    done < <(printRtests)
    export DIC_RTESTS=${DIC_RTESTS}
}

makeLogs()
{
    rtest=`prepareRtestName $1`
    REF_FILE="$REFERENCES/$rtest"
    OUTPUT_FILE="$OUTPUTS/$rtest"
    echo "######## START LOG OF THE $rtest ########"
    echo "diff -u $REF_FILE $OUTPUT_FILE"
    diff -u $REF_FILE $OUTPUT_FILE
    echo "######## STOP LOG OF THE $rtest ########"
}
prepareRtestName()
{
    #echo "RTEST: $1"
    if [ -z ${1+$1} ]; then
        $echoerror "You need set at last one param" ; kill -s TERM $$
    fi

    # check dictionary
    for i in "${!DIC_RTESTS[@]}"; do
        if [[ "$i" == "$1" ]] || [[ "${DIC_RTESTS[$i]}" == "$1" ]];
        then
            echo "${DIC_RTESTS[$i]}"
            return
        fi
    done
}

fixEnvVar()
{
    COMMAND="$*"
    while read key value ; do COMMAND=${COMMAND//\$$key/$value} ; done < <(env | awk -F '=' '{print $1" "$2}')
    printf "${COMMAND}"
}
maketest()
{
    rtest=`prepareRtestName $1`

    REF_FILE="$REFERENCES/$rtest"
    OUTPUT_FILE="$OUTPUTS/$rtest"
    COMMAND=""
    linenumber=`printf "${TEST_CASE_CONTENT}" | grep -nw $rtest | grep 'BEGIN_TEST' | awk -F ':' '{print $1}'`
    ((linenumber=linenumber+1))
    while read -r line;
    do
        if [[ $line == *"END_TEST"* ]]; then
            break;
        fi
        COMMAND=$"${COMMAND} ${line}"
    done < <(set -f ; tail -n +$linenumber <(printf "${TEST_CASE_CONTENT}") ; set +f)
    if [ ! -f $REF_FILE ];
    then
        echo "RTEST to fill" > $REF_FILE
    fi
    LOGCOMMAND=`fixEnvVar "${COMMAND}"`
    log=`printf "\n######## COMMAND OF THE ${rtest}\n\t\t${LOGCOMMAND}\n######## ########\n"`
    printf "$log" >> $LOGS/rtest.log
    if [[ $2 != '--quiet' ]] || [[ `whoami` == 'root' ]];
    then
        printf "$log\n"
    fi
    printf "TESTING $rtest ..."

    #SET PATH and LD_LIBRARY_PATH
    COMMAND=$"export PATH=$PATHDIR:$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATHDIR:$LD_LIBRARY_PATH; ${COMMAND}"

    bash -c "${COMMAND}" &> $OUTPUT_FILE
    if [[ $2 == '--update' ]];
    then
        cp $OUTPUT_FILE $REF_FILE
        printf "${BLUE}UPDATED${END}\n$REF_FILE updated\n"
        cat $REF_FILE

    else    #otherwise print the result

        cmp --silent $OUTPUT_FILE $REF_FILE
        if [[ $? == 0 ]];
        then
            printf "${GREEN}SUCCESS${END}\n"
        else
            errmsg=1
            printf "${RED}FAILED${END}\n"
            log=`makeLogs $rtest`
            printf "\n$log\n" >> $LOGS/rtest.log
            if [[ $2 != '--quiet' ]] || [[ `whoami` == 'root' ]];
            then
                printf "\n$log\n"
            fi
        fi
    fi
}

####################### USAGE #################
if [[ "$RSUITE" == 'TRUE' ]]; #change suite
then
    if [ ! -z ${RSUITE_VAL+$RSUITE_VAL} ];
    then
        PREV_CASE="$TEST_CASE"
        export TEST_CASE=`FixSuiteName "${RSUITE_VAL}"`

        if [[ -f "$TEST_CASE" ]];
        then
            echo "Previous testcase $PREV_CASE has switched to the $TEST_CASE"
            echo "$TEST_CASE" > $SUITES/current
        else
            printf "\nPrevious testcase $PREV_CASE has switched to the ${YELLOW}NEW FILE${END} $TEST_CASE\n"
            echo "$TEST_CASE" > $SUITES/current
            exit "$errmsg"
        fi
    else
        i=0
        while IFS= read line;
        do
            echo "$i":"$line"
            ((i=i+1));
        done < <(find $SUITES/ -type f | grep -v "\.swp$\|default$\|current$")
        exit "$errmsg"
    fi
fi
fillRtestDict

if [[ $1 == 'h' ]] || [[ $1 == '-h' ]] || [[ $1 == '--help' ]]; #update specific test
then
    printf "$USAGE"

elif [[ $2 == 'p' ]] || [[ $2 == '-p' ]] || [[ $2 == '--print' ]]; #update specific test
then
    rtest=`prepareRtestName $1`
    REF_FILE="$REFERENCES/$rtest"
    echo $REF_FILE
    cat $REF_FILE

elif [[ $1 == 'e' ]] || [[ $1 == '-e' ]] || [[ $1 == '--edit' ]]; #edit suite
then
    vim $TEST_CASE

elif [[ $1 == 'r' ]] || [[ $1 == '-r' ]] || [[ $1 == '--run' ]]; #run all
then
    echo > $LOGS/rtest.log
    for i in "${!DIC_RTESTS[@]}"; do
        printf "$i: "
        maketest "${DIC_RTESTS[$i]}" --quiet
    done
    printf "\n\tTo learn more see: $LOGS/rtest.log\n"
    elif [[ $1 == 'l' ]] || [[ $1 == '-l' ]] || [[ $1 == '--logs' ]]; #update specific test
then
    vim $LOGS/rtest.log

elif [[ $2 == 'u' ]] || [[ $2 == '-u' ]] || [[ $2 == '--update' ]]; #update specific test
then
    echo > $LOGS/rtest.log
    maketest $1 --update

elif [ ! -z ${1+$1} ]; #pass one or more rtests e.g: 1 name-of-second-rtest 7 ; or sequence 2 - 3
then
    echo > $LOGS/rtest.log
    if (( $# == 1 ));
    then
        maketest "$1"
    else
        for (( i=1; i<=$#; i++));
        do
            if [[ "${!i}" == '-' ]];
            then
                k=i
                ((prev=k-1))
                prev=${!prev}
                ((next=k+1))
                next=${!next}
                if (( "$prev" < "$next" ));
                then
                    ((prev=prev+1))
                    for (( j="$prev"; j<$next; j++)); do
                        maketest "$j" --quiet
                    done
                elif (( "$prev" > "$next" ));
                then
                    $echoerror "Previous number \"$prev\" is smaler or equal than \"$next\"" ; kill -s TERM $$
                fi
            else
                maketest "${!i}" --quiet
            fi
        done
    fi
    printf "\n\tTo learn more see: $LOGS/rtest.log\n"

else    #print list of tests

    for i in "${!DIC_RTESTS[@]}"; do
        printf "$i:${DIC_RTESTS[$i]}\n"
    done
fi
if [ -z ${BASH_SOURCE- } ];
then
    exit "$errmsg"
fi

