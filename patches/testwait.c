/* this is a place holder.
 * replace with your own code
 */

#include "types.h"
#include "user.h"

int test_waitpid(){
    // return 0 if success

    // 1) wait for non existing child
    int x = waitpid(124);
    if(x != -1){
	    printf(1,"fail. Should return -1\n");
    }
    // 2) fork a child, then wait for it to terminate
    int child_pid = fork();
    if(child_pid == 0){
        // in child
        sleep(10);
        return 0;
    }else{
        // in parent
        int ret = waitpid(child_pid);
        if(ret == -1){
            printf(1,"error calling waitpid");
            return 1;
        } else return 0;
    }
}


int main(){
    printf(1,"hello from testwait\n");
    test_waitpid();
    exit();
}
