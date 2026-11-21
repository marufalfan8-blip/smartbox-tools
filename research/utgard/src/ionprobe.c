/* SPDX-License-Identifier: MIT */
/* Probe ION ioctl numbers on Amlogic 3.14: try ALLOC nr 0..7 with struct
 * variants, report which one succeeds. Read-only-ish: allocates small buffers. */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

struct alloc32 { uint32_t len, align, heap, flags, handle; };
struct alloc64 { unsigned long len, align; uint32_t heap, flags; void *handle; };

static unsigned ioctl_code(int nr, int size) { return (3u<<30)|(size<<16)|('I'<<8)|nr; }

int main(void){
    int fd=open("/dev/ion",O_RDONLY);
    if(fd<0){perror("open ion");return 1;}
    printf("ion fd=%d\n",fd);
    for(int nr=0;nr<8;nr++){
        for(int variant=0;variant<2;variant++){
            if(variant==0){
                struct alloc32 a; memset(&a,0,sizeof a);
                a.len=0x1000; a.align=0x1000; a.heap=1;
                unsigned c=ioctl_code(nr,sizeof a);
                int r=ioctl(fd,c,&a);
                printf("nr=%d v32 size=%zu code=0x%08x -> r=%d handle=%u\n",nr,sizeof a,c,r,a.handle);
            } else {
                struct alloc64 a; memset(&a,0,sizeof a);
                a.len=0x1000; a.align=0x1000; a.heap=1;
                unsigned c=ioctl_code(nr,sizeof a);
                int r=ioctl(fd,c,&a);
                printf("nr=%d v64 size=%zu code=0x%08x -> r=%d handle=%p\n",nr,sizeof a,c,r,a.handle);
            }
        }
    }
    close(fd); return 0;
}
