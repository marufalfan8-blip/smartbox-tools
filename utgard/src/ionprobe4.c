/* Probe ION_IOC_CUSTOM: find nr + cmd that returns a physical address.
 * Uses fd from ION_SHARE (nr=4, size8). */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

struct alloc64 { unsigned long len, align; uint32_t heap, flags; void *handle; };
struct fd32 { uint32_t handle, fd; };
struct physdata { uint32_t fd, addr, size; };
struct custom16 { uint32_t cmd, arg; };      /* arg as 32-bit ptr */
struct custom24 { uint32_t cmd; unsigned long arg; }; /* arg 64-bit */
static unsigned ic(int nr,int sz){return (3u<<30)|(sz<<16)|('I'<<8)|nr;}

int main(void){
    int ion=open("/dev/ion",O_RDONLY);
    struct alloc64 a; memset(&a,0,sizeof a); a.len=0x1000;a.align=0x1000;a.heap=1;
    ioctl(ion,ic(0,sizeof a),&a);
    struct fd32 f={.handle=(uint32_t)(uintptr_t)a.handle,.fd=0xffffffff};
    if(ioctl(ion,ic(4,sizeof f),&f)<0){printf("SHARE fail\n");return 1;}
    printf("SHARE fd=%u\n",f.fd);
    /* try CUSTOM nr with various cmd codes and struct sizes */
    for(int nr=1;nr<=8;nr++){
        for(uint32_t cmd=0x4900;cmd<=0x4910;cmd++){
            struct physdata p; memset(&p,0,sizeof p); p.fd=f.fd;
            struct custom24 cd={.cmd=cmd,.arg=(unsigned long)&p};
            if(ioctl(ion,ic(nr,sizeof cd),&cd)==0 && p.addr)
                printf("CUSTOM nr=%d cmd=0x%x sz24 -> addr=0x%x size=%u\n",nr,cmd,p.addr,p.size);
        }
    }
    close(ion); return 0;
}
