// This program tests the implementation of signals (in xv6)

#include "types.h"
#include "user.h"
#include "signal.h"

typedef int pid_t;


void my_handler(int sig){
    printf(1,"signal handler called with signal=%d\n", sig);
}

// test the simple case: child process registers a handler, the parent signals the child
void test_simple_handling(){
     printf(1,"%s starts\n", __FUNCTION__ );
    int child_pid = fork();
    if(child_pid < 0){
        printf(1,"fork failed");
        exit();
    }
    if(child_pid == 0){
        // in child
        signal(SIGHUP, my_handler);
        for(int i =0; i < 3;i++) {
            sleep(1);
        }
        exit();
    }else {
        // parent
        sigsend(child_pid, SIGHUP); // send the signal type that the child expects
        wait();
    }
    printf(1,"%s completed\n\n", __FUNCTION__ );

}

// test the use case that a parent sets a signal , and a child inherits it.
void test_inheritance(){
    printf(1,"%s starts\n", __FUNCTION__ );
    signal(SIGHUP, SIG_IGN);
    
    int child_pid = fork();
    if(child_pid < 0){
        printf(1,"fork failed");
        exit();
    }
    if(child_pid == 0){
        // in child
        for(int i =0; i < 3;i++) {
            sleep(1);
        };
        exit();
    }else {
        // parent
        signal(SIGHUP, my_handler); // change the handler, and we want to see that the child is not affected.
        sigsend(child_pid, SIGHUP); // expected result: the child ignores this signal
        wait();
    }
    
    printf(1,"%s completed\n\n", __FUNCTION__ );
}

// the default action for all signals is to print a message
void test_default(){
    printf(1,"%s starts\n", __FUNCTION__ );
    int child_pid = fork();
    if(child_pid < 0){
        printf(1,"fork failed");
        exit();
    }
    if(child_pid == 0){
        // in child
        for(int i =0; i < 3;i++) {
            sleep(1);
        }
        exit();
    }else {
        // parent
        sigsend(child_pid, SIGALRM);
        wait();
    }
    printf(1,"%s completed\n\n", __FUNCTION__ );
}

/* verify we can set signals to be ignored.
 * The signals SIGKILL and SIGSTOP cannot be caught or ignored.
 */
void test_ignore(){
    printf(1,"%s starts\n", __FUNCTION__ );
    int child_pid = fork();
    if(child_pid < 0){
        printf(1,"fork failed");
        exit();
    }
    if(child_pid == 0){
        // in child
       sighandler_t ret = signal(SIGTERM, SIG_IGN); // ignore TERMINATE
       if(ret == SIG_ERR){
           printf(1,"FAILED\n");
           return;
       }
       ret = signal(SIGSTOP,SIG_IGN); // impossible to ignore SIGSTOP
       if(ret != SIG_ERR){
           printf(1,"FAILED\n");
           return;
       }
       for(int i =0; i < 3;i++) {
            sleep(1);
       }
       exit();
    }else {
        // parent
        sleep(1);
        sigsend(child_pid, SIGTERM);
        wait();
    }
    printf(1,"%s completed\n\n", __FUNCTION__ );
}

void test_bad_value(){
    printf(1,"%s starts\n", __FUNCTION__ );
    sighandler_t ret = signal(588,0);
    if(ret >=0){
        // do NOT check it this year since there is a waiver on return code of signal()
        //printf(1,"%s: FAIL! signal should fail\n", __FUNCTION__ );
    }

    sigsend(42, SIGALRM);
    if(ret ==0){
        printf(1,"%s: FAIL! sigsend should fail\n", __FUNCTION__ );
    }
    printf(1,"%s completed\n\n", __FUNCTION__ );
}

int main(int ac, char** av){
    test_simple_handling();
    test_default();
    test_ignore();
    test_inheritance();
    test_bad_value();

    exit();
}

