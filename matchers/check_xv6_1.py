"""
check result of running hw 1 (4) of xv6 in 94210

Check if two text files are considered equal for cours

>>> from tester_xv6 import check
>>> check("50_output.txt", "50_output_permuted.txt")
True
"""

import re
import sys
#from serverpkg.server_codes import ExitCode
#from frozendict import frozendict


class RegexError(BaseException):
    pass


class ParseError(BaseException):
    pass
    

# if user types the command:
regex = r"lsproc\s*\nname\s+pid\s+state\s+address\s+\ninit\s+1\s+SLEEPING\s+[0-9a-f]{8}\s+\nsh\s+2\s+SLEEPING\s+[0-9a-f]{8}\s+\nlsproc\s+3\s+RUNNING\s+[0-9a-f]{8}\s+"

regex = r"name\s+pid\s+state\s+address\s*\ninit\s+1\s+SLEEPING\s+[0-9a-f]{8}\s*\nlsproc\s+2\s+RUNNING\s+[0-9a-f]{8}\s*"

def check(file_name_a):
    """
    check if the two input files are considered equal, for the purpose of this specific homework

    :param file_name_a: output of one run
    :param file_name_b: output of another run
    :return: 0 if the files are equal (the content might be not identical)
    """
    with open(file_name_a,'r') as f:
        tested_output = f.read()
    isMatch = _match(tested_output)
    if not isMatch:
        print("Your output:\n" + tested_output)
    return 0 if isMatch else 42

def _match(string):
    prog = re.compile(regex)
    result = prog.findall(string)
    print(str(result))
    return len(result) == 1

if __name__ == "__main__":
   
    #print("comparing {} and {}".format(sys.argv[1], sys.argv[2]))
    good = check(sys.argv[1])
    exit(good)
    
    
