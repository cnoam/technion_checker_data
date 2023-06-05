int bitAnd(int x, int y);
int getByte(int x, int n);
int logicalShift(int x,int n);
#include <assert.h>
int main(){
    assert(3 == bitAnd(3,7));
    assert(0xba ==  getByte(0xba00dd,2));
    assert( 2 == logicalShift(64, 5));
    return 0;
}