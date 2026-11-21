/* Last ION probe: old-style structs (32-bit handle) + alt magic bytes */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>

struct alloc32 { uint32_t len, align, heap, flags, handle; };
struct fd32 { uint32_t handle, fd; };
struct alloc64 { unsigned long len, align; uint32_t heap, flags; void *handle; };
static unsigned ic(int magic,int nr,int sz){return (3u<<30)|(sz<<16)|(magic<<8)|nr;}

int main(void){
    int ion=open("/dev/ion",O_RDONLY);
    /* ALLOC variants */
    struct alloc64 a64; memset(&a64,0,sizeof a64); a64.len=0x1000;a64.align=0x1000;a64.heap=1;
    struct alloc32 a32; memset(&a32,0,sizeof a32); a32.len=0x1000;a32.align=0x1000;a32.heap=1;
    printf("ALLOC64 r=%d h=%p\n",ioctl(ion,ic('I',0,sizeof a64),&a64),a64.handle);
    printf("ALLOC32 r=%d h=%u\n",ioctl(ion,ic('I',0,sizeof a32),&a32),a32.handle);
    int magics[]={'I','i','A','M',0x49,0x69};
    for(int mi=0;mi<6;mi++){
        for(int nr=1;nr<=8;nr++){
            struct fd32 f={.handle=1,.fd=0xffffffff};
            int r=ioctl(ion,ic(magics[mi],nr,sizeof f),&f);
            if(r==0) printf("MAGIC=0x%02x nr=%d -> OK fd=%u !!!\n",magics[mi],nr,f.fd);
        }
    }
    close(ion); return 0;
}
