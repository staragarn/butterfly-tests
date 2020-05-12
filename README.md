############# butterfly-tests (bash script)
# Scripts allows to make, save and match tests with their references

#TODO
- mkdir -p TESTS/{inputs,outputs,references,others,suites,scripts}  
- ./rtest.sh -help

#steps to first tests
- ./rtest.sh -e #open by vim files with definitions of the tests
##example:
#BEGIN_TEST buterfly_test
# echo "my first ";
# echo "test";
#END_TEST buterfly_test
- ./rtest.sh -r                          #run all tests from above edited file
#OR
- ./rtest.sh                             #list all "current" testcases
- ./rtest.sh 1 or ./rtest buterfly_test  #run single test by number or test_name

