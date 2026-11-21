/* SPDX-License-Identifier: MIT */
/* Get phys of an ION allocation: try mmap of ion fd and dma-buf fd,
 * then read /proc/self/pagemap for the mapped VA (may be EPERM), and
 * also try the Mali GPU's own MEM_QUERY if available. */
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
struct fd32 { uint32_t handle, fd; };
static unsigned ic(int nr,int sz){return (3u<<30)|(sz<<16)|('I'<<8)|nr;}

int main(void){
    int ion=open("/dev/ion",O_RDONLY);
    struct alloc64 a; memset(&a,0,sizeof a); a.len=0x1000;a.align=0x1000;a.heap=1;
    int ar=ioctl(ion,ic(0,sizeof a),&a); printf("ALLOC r=%d handle=%p\n",ar,a.handle);
    struct fd32 f={.handle=(uint32_t)(uintptr_t)a.handle,.fd=0xffffffff};
    int sr=ioctl(ion,ic(4,sizeof f),&f); printf("SHARE r=%d fd=%d\n",sr,f.fd);
    /* try mmap ion fd directly and dmabuf fd */
    for(int which=0;which<2;which++){
        int fd=(which==0)?ion:f.fd;
        void *m=mmap(NULL,0x1000,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
        printf("mmap %s -> %p errno=%d\n",which?"dmabuf":"ionfd",m,errno);
        if(m!=MAP_FAILED){
            uint64_t e=0; int pm=open("/proc/self/pagemap",O_RDONLY);
            ssize_t n=pread(pm,&e,8,((uintptr_t)m/0x1000)*8);
            printf("  pagemap n=%zd e=0x%llx\n",n,(unsigned long long)e);
            close(pm); munmap(m,0x1000);
        }
    }
    close(ion); return 0;
}
