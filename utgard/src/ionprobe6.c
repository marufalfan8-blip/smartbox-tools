/* Try direct ION ioctl nr 0..15 with phys struct {uint32 fd,addr,size} */
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
static unsigned ic(int nr,int sz){return (3u<<30)|(sz<<16)|('I'<<8)|nr;}
int main(void){
    int ion=open("/dev/ion",O_RDONLY);
    struct alloc64 a; memset(&a,0,sizeof a); a.len=0x1000;a.align=0x1000;a.heap=1;
    ioctl(ion,ic(0,sizeof a),&a);
    struct fd32 f={.handle=(uint32_t)(uintptr_t)a.handle,.fd=0xffffffff};
    ioctl(ion,ic(4,sizeof f),&f);
    printf("fd=%d\n",f.fd);
    for(int nr=0;nr<16;nr++){
        for(int sz=8;sz<=32;sz+=4){
            struct physdata p; memset(&p,0,sizeof p); p.fd=f.fd;
            int r=ioctl(ion,ic(nr,sz),&p);
            if(r==0 && p.addr) printf("nr=%d sz=%d -> addr=0x%x size=%u\n",nr,sz,p.addr,p.size);
        }
    }
    close(ion);return 0;
}
