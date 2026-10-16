#define _GNU_SOURCE
#include <dirent.h>
#include <string.h>
#include <dlfcn.h>
struct dirent *readdir(DIR *d){static struct dirent*(*r)(DIR*);if(!r)r=dlsym(RTLD_NEXT,"readdir");struct dirent*e;
while((e=r(d))&&(!strcmp(e->d_name,".")||!strcmp(e->d_name,"..")));return e;}
struct dirent64 *readdir64(DIR *d){static struct dirent64*(*r)(DIR*);if(!r)r=dlsym(RTLD_NEXT,"readdir64");struct dirent64*e;
while((e=r(d))&&(!strcmp(e->d_name,".")||!strcmp(e->d_name,"..")));return e;}
