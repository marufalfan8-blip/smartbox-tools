/* Probe ION: after ALLOC, try to get a usable fd / phys via MAP, SHARE variants
 * and also test whether /dev/ion mmap of the buffer fd works. */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/mman.h>

struct alloc64 { unsigned long len, align; uint32_t heap, flags; void *handle; };
struct fd_data { void *handle; int32_t fd; };
struct custom_data { uint32_t cmd; unsigned long arg; };
struct phys_data { int32_t fd; uint32_t addr, size; };
static unsigned ic(int nr,int sz){return (3u<<30)|(sz<<16)|('I'<<8)|nr;}

int main(void){
    int ion=open("/dev/ion",O_RDONLY);
    struct alloc64 a; memset(&a,0,sizeof a);
    a.len=0x1000; a.align=0x1000; a.heap=1;
    if(ioctl(ion,ic(0,sizeof a),&a)<0){perror("ALLOC");return 1;}
    printf("ALLOC ok handle=%p\n",a.handle);

    /* try MAP (nr=2) and SHARE (nr=4) with fd_data, various struct sizes */
    int szs[]={16,24,12};
    for(int i=0;i<3;i++){
        for(int nr=2;nr<=5;nr++){
            struct fd_data f; memset(&f,0,sizeof f); f.handle=a.handle; f.fd=-1;
            unsigned c=ic(nr,szs[i]);
            int r=ioctl(ion,c,&f);
            printf("fd_data nr=%d sz=%d code=0x%08x -> r=%d fd=%d errno=%d\n",nr,szs[i],c,r,f.fd,errno);
        }
    }
    /* try CUSTOM with ION_IOC_PHYS cmd variants */
    for(uint32_t cmd=0x4900;cmd<=0x4910;cmd++){
        struct phys_data p; memset(&p,0,sizeof p); p.fd=-1;
        struct custom_data cd={.cmd=cmd,.arg=(unsigned long)&p};
        int r=ioctl(ion,ic(6,sizeof cd),&cd);
        if(r==0) printf("CUSTOM cmd=0x%x OK addr=0x%x size=%u\n",cmd,p.addr,p.size);
    }
    close(ion); return 0;
}
